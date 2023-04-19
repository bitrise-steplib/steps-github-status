package main

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestGetState(t *testing.T) {
	testCases := []struct {
		name string
		cfg  config
		want string
	}{
		{
			name: "not auto State returns State",
			cfg:  config{State: "error"},
			want: "error",
		},
		{
			name: "both Pipeline and Workflow succeeds returns success",
			cfg:  config{State: "auto", PipelineBuildStatus: "succeeded", BuildStatus: "0"},
			want: "success",
		},
		{
			name: "Pipeline succeeds with abort returns success",
			cfg:  config{State: "auto", PipelineBuildStatus: "succeeded_with_abort", BuildStatus: "0"},
			want: "success",
		},
		{
			name: "Pipeline fails but Workflow succeeds returns failure",
			cfg:  config{State: "auto", PipelineBuildStatus: "failure", BuildStatus: "0"},
			want: "failure",
		},
		{
			name: "Pipeline succeeds but Workflow fails returns failure",
			cfg:  config{State: "auto", PipelineBuildStatus: "succeeded", BuildStatus: "1"},
			want: "failure",
		},
		{
			name: "both Pipeline and Workflow fails returns failure",
			cfg:  config{State: "auto", PipelineBuildStatus: "failure", BuildStatus: "1"},
			want: "failure",
		},
	}
	for _, testCase := range testCases {
		t.Run(
			testCase.name, func(t *testing.T) {
				actual := getState(testCase.cfg)
				require.Equal(t, testCase.want, actual)
			},
		)
	}
}
