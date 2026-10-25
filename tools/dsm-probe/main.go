// dsm-probe: reproduce the synology_api write problem outside Terraform.
//
// Logs in exactly like the provider (same go-synology library, same env vars),
// then changes ONE setting, the minute of the `git` share's snapshot schedule,
// two different ways and reads it back after each:
//
//   A. provider path: api.GetQuery (GET, session in the query string)
//   B. browser path:  POST form + X-SYNO-TOKEN header (what DSM's UI sends)
//
// It finishes by restoring the minute to 20. It never prints the password,
// OTP, session ID or token.
//
// Env: SYNOLOGY_HOST, SYNOLOGY_USER, SYNOLOGY_PASSWORD, SYNOLOGY_OTP_SECRET
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"reflect"
	"strings"

	"github.com/hashicorp/go-retryablehttp"
	"github.com/synology-community/go-synology/pkg/api"
)

const share = "git"
const taskID = "18"

var secretKeys = []string{"_sid", "SynoToken", "passwd", "otp_code", "account"}

func redact(u *url.URL) string {
	c := *u
	q := c.Query()
	for _, k := range secretKeys {
		if q.Has(k) {
			q.Set(k, "REDACTED")
		}
	}
	c.RawQuery = q.Encode()
	s, _ := url.QueryUnescape(c.String())
	return s
}

// Same reflection trick the provider's synology_api resource uses.
func params(m map[string]string) any {
	sf := []reflect.StructField{}
	for k, v := range m {
		sf = append(sf, reflect.StructField{Name: strings.ToTitle(k), Type: reflect.TypeOf(v), Tag: reflect.StructTag(fmt.Sprintf(`url:"%s"`, k))})
	}
	s := reflect.New(reflect.StructOf(sf)).Elem()
	for k, v := range m {
		s.FieldByName(strings.ToTitle(k)).Set(reflect.ValueOf(v))
	}
	return s.Interface()
}

func schedule(min int) string {
	b, _ := json.Marshal(map[string]any{"date_type": 0, "week_name": "0,1,2,3,4,5,6", "hour": 0, "min": min, "repeat_hour": 1, "repeat_min": 0, "last_work_hour": 23})
	return string(b)
}

func setParams(min int) map[string]string {
	return map[string]string{"name": share, "enable_snapshot_schedule": "true", "schedule": schedule(min), "task_id": taskID}
}

var setMethod = api.Method{API: "SYNO.Core.Share.Snapshot", Method: "set_schedule", Version: 1}

func readMin(ctx context.Context, cli api.Api) string {
	r, err := api.GetQuery[map[string]any](cli, ctx, params(map[string]string{"name": share}),
		api.Method{API: "SYNO.Core.Share.Snapshot", Method: "get_schedule", Version: 1})
	if err != nil {
		return "READ ERROR: " + err.Error()
	}
	sch, _ := (*r)["schedule"].(map[string]any)
	return fmt.Sprintf("min=%v task_id=%v enabled=%v", sch["min"], (*r)["task_id"], (*r)["enable_snapshot_schedule"])
}

func viaGetQuery(ctx context.Context, cli api.Api, min int) string {
	r, err := api.GetQuery[map[string]any](cli, ctx, params(setParams(min)), setMethod)
	if err != nil {
		return "ERROR: " + err.Error()
	}
	b, _ := json.Marshal(r)
	return "data: " + string(b)
}

func viaPost(ctx context.Context, cli api.Api, min int) string {
	creds := cli.Credentials()
	form := url.Values{"api": {setMethod.API}, "method": {setMethod.Method}, "version": {"1"}, "_sid": {creds.SessionID}}
	for k, v := range setParams(min) {
		form.Set(k, v)
	}
	u := *cli.BaseUrl()
	u.RawQuery = ""
	req, _ := retryablehttp.NewRequestWithContext(ctx, http.MethodPost, u.String(), strings.NewReader(form.Encode()))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("X-SYNO-TOKEN", creds.Token)
	resp, err := cli.Client().Do(req)
	if err != nil {
		return "ERROR: " + err.Error()
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(resp.Body)
	return "raw: " + string(b)
}

func main() {
	ctx := context.Background()
	cli, err := api.New(api.Options{Host: os.Getenv("SYNOLOGY_HOST"), VerifyCert: false, RetryLimit: 1})
	if err != nil {
		fmt.Println("client error:", err)
		os.Exit(1)
	}
	cli.Client().RequestLogHook = func(_ retryablehttp.Logger, r *http.Request, _ int) {
		fmt.Printf("    -> %s %s\n", r.Method, redact(r.URL))
	}
	cli.Client().Logger = nil

	fmt.Println("== login as", os.Getenv("SYNOLOGY_USER"))
	if _, err := cli.Login(ctx, api.LoginOptions{Username: os.Getenv("SYNOLOGY_USER"), Password: os.Getenv("SYNOLOGY_PASSWORD"), OTPSecret: os.Getenv("SYNOLOGY_OTP_SECRET")}); err != nil {
		fmt.Println("login error:", err)
		os.Exit(1)
	}
	c := cli.Credentials()
	fmt.Printf("    session id present=%v, syno token present=%v\n", c.SessionID != "", c.Token != "")

	fmt.Println("== 0. read before:", readMin(ctx, cli))
	fmt.Println("== A. set min=21 via provider path (GetQuery):")
	fmt.Println("   ", viaGetQuery(ctx, cli, 21))
	fmt.Println("   read after A:", readMin(ctx, cli))
	fmt.Println("== B. set min=22 via browser path (POST + X-SYNO-TOKEN):")
	fmt.Println("   ", viaPost(ctx, cli, 22))
	fmt.Println("   read after B:", readMin(ctx, cli))
	fmt.Println("== restore min=20 via B:")
	fmt.Println("   ", viaPost(ctx, cli, 20))
	fmt.Println("   read final:", readMin(ctx, cli))
}
