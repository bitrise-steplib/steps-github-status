package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httputil"
	"os"
	"strings"

	"github.com/bitrise-io/go-steputils/stepconf"
	"github.com/bitrise-io/go-utils/log"
	"github.com/bitrise-io/go-utils/retry"
	"github.com/hashicorp/go-retryablehttp"
)

type config struct {
	AuthToken     string `env:"auth_token,required"`
	RepositoryURL string `env:"repository_url,required"`
	CommitHash    string `env:"commit_hash,required"`
	APIURL        string `env:"api_base_url"`

	State            string `env:"set_specific_status,opt[auto,pending,success,error,failure]"`
	BuildURL         string `env:"build_url"`
	StatusIdentifier string `env:"status_identifier"`
	Description      string `env:"description"`
	Verbose          bool   `env:"verbose"`
}

type statusRequest struct {
	State       string `json:"state"`
	TargetURL   string `json:"target_url,omitempty"`
	Description string `json:"description,omitempty"`
	Context     string `json:"context,omitempty"`
}

// ownerAndRepo returns the owner and the repository part of a git repository url. Possible url formats:
// - https://hostname/owner/repository.git
// - git@hostname:owner/repository.git
func ownerAndRepo(url string) (string, string) {
	url = strings.TrimPrefix(strings.TrimPrefix(url, "https://"), "git@")
	a := strings.FieldsFunc(url, func(r rune) bool { return r == '/' || r == ':' })
	return a[1], strings.TrimSuffix(a[2], ".git")
}

func getState(preset string) string {
	if preset != "auto" {
		return preset
	}

	pipelineBuildStatus := os.Getenv("BITRISEIO_PIPELINE_BUILD_STATUS")
	if pipelineBuildStatus == "succeeded" {
		return "success"
	} else if pipelineBuildStatus == "failed" {
		return "failure"
	}

	workflowBuildStatus := os.Getenv("BITRISE_BUILD_STATUS")
	if workflowBuildStatus == "0" {
		return "success"
	}
	return "failure"
}

func getDescription(desc, state string) string {
	if desc == "" {
		return strings.Title(getState(state))
	}
	return desc
}

func httpDump(req *http.Request, resp *http.Response) (string, error) {
	responseStr, err := httputil.DumpResponse(resp, true)
	if err != nil {
		return "", fmt.Errorf("unable to dump response, error: %s", err)
	}

	requestStr, err := httputil.DumpRequest(req, true)
	if err != nil {
		return "", fmt.Errorf("unable to dump request, error: %s", err)
	}

	return "Request: " + string(requestStr) + "\nResponse: " + string(responseStr), nil
}

// createStatus creates a commit status for the given commit.
// see also: https://developer.github.com/v3/repos/statuses/#create-a-status
// POST /repos/:owner/:repo/statuses/:sha
func createStatus(cfg config) error {
	owner, repo := ownerAndRepo(cfg.RepositoryURL)
	url := fmt.Sprintf("%s/repos/%s/%s/statuses/%s", cfg.APIURL, owner, repo, cfg.CommitHash)

	body, err := json.Marshal(statusRequest{
		State:       getState(cfg.State),
		TargetURL:   cfg.BuildURL,
		Description: getDescription(cfg.Description, cfg.State),
		Context:     cfg.StatusIdentifier,
	})
	if err != nil {
		return err
	}
	req, err := retryablehttp.NewRequest("POST", url, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Add("Authorization", "token "+cfg.AuthToken)

	client := retry.NewHTTPClient()
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send the request: %s", err)
	}

	defer func() {
		if err := resp.Body.Close(); err != nil {
			log.Errorf("Error when closing HTTP response body:", err)
		}
	}()

	if resp.StatusCode != 201 || cfg.Verbose {
		d, err := httpDump(req.Request, resp)
		if err != nil {
			return err
		}
		fmt.Println(d)
	}

	if resp.StatusCode != 201 {
		return fmt.Errorf("server error, unexpected status code: %s", resp.Status)
	}

	return nil
}

func main() {
	var cfg config
	if err := stepconf.Parse(&cfg); err != nil {
		log.Errorf("Error: %s\n", err)
		os.Exit(1)
	}
	stepconf.Print(cfg)

	if err := createStatus(cfg); err != nil {
		log.Errorf("Error: %s\n", err)
		os.Exit(1)
	}
}
