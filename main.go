package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"

	"github.com/bitrise-io/go-utils/log"
	"github.com/bitrise-tools/go-steputils/stepconf"
)

type config struct {
	AuthToken     string `env:"auth_token,required"`
	RepositoryURL string `env:"repository_url,required"`
	CommitHash    string `env:"commit_hash,required"`
	APIURL        string `env:"api_base_url"`

	State            string `env:"set_specific_status,opt[auto,pending,success,error,failure]"`
	BuildURL         string `env:"build_url"`
	StatusIdentifier string `env:"status_identifier"`
}

type statusRequest struct {
	State       string `json:"state"`
	TargetURL   string `json:"target_url,omitempty"`
	Description string `json:"description,omitempty"`
	Context     string `json:"context,omitempty"`
}

// getOwner get the owner part of a git repository url. Possible url formats:
// - https://hostname/owner/repository.git
// - git@hostname:owner/repository.git
func getOwner(url string) string {
	url = strings.TrimPrefix(strings.TrimPrefix(url, "https://"), "git@")
	return strings.FieldsFunc(url, func(r rune) bool { return r == '/' || r == ':' })[1]
}

// getOwner get the repository part of a git repository url. Possible url formats:
// - https://hostname/owner/repository.git
// - git@hostname:owner/repository.git
func getRepo(url string) string {
	url = strings.TrimPrefix(strings.TrimPrefix(url, "https://"), "git@")
	repo := strings.FieldsFunc(url, func(r rune) bool { return r == '/' || r == ':' })[2]
	return strings.TrimSuffix(repo, ".git")
}

func getState(preset string) string {
	if preset != "auto" {
		return preset
	}
	if os.Getenv("BITRISE_BUILD_STATUS") == "0" {
		return "success"
	}
	return "failure"
}

// createStatus creates a commit status for the given commit.
// see also: https://developer.github.com/v3/repos/statuses/#create-a-status
// POST /repos/:owner/:repo/statuses/:sha
func createStatus(cfg config) error {
	format := "%s/repos/%s/%s/statuses/%s"
	url := fmt.Sprintf(format, cfg.APIURL, getOwner(cfg.RepositoryURL), getRepo(cfg.RepositoryURL), cfg.CommitHash)

	body, err := json.Marshal(statusRequest{
		State:       getState(cfg.State),
		TargetURL:   cfg.BuildURL,
		Description: strings.Title(getState(cfg.State)),
		Context:     cfg.StatusIdentifier,
	})
	if err != nil {
		return err
	}

	req, err := http.NewRequest("POST", url, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Add("Authorization", "token "+cfg.AuthToken)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send the request: %s", err)
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			log.Warnf(err.Error())
		}
	}()

	return err
}

func main() {
	if os.Getenv("commit_hash") == "" {
		log.Warnf("GitHub requires a commit hash for build status reporting")
		os.Exit(1)
	}

	var cfg config
	if err := stepconf.Parse(&cfg); err != nil {
		log.Errorf("Error: %s\n", err)
		os.Exit(1)
	}
	stepconf.Print(cfg)

	err := createStatus(cfg)
	if err != nil {
		log.Errorf("Error: %s\n", err)
		os.Exit(1)
	}
}
