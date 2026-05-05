package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestIdC(t *testing.T) {
	t.Log("Starting ACF AWS IdC Module test")

	terraformDir := "../../examples/complete"
	stateKey := "terratest/terraform-aws-acf-idc.tfstate"
	backendConfig := loadBackendConfig(t, stateKey)

	// Step 1: Create the CICD provisioner IAM roles (org-mgmt + core-security).
	terraformPreparation := &terraform.Options{
		TerraformBinary: getHclBinary(),
		TerraformDir:    terraformDir,
		NoColor:         false,
		Lock:            true,
		BackendConfig:   backendConfig,
		Reconfigure:     true,
		Targets: []string{
			"module.create_provisioner_idc",
			"module.create_provisioner_reporting",
		},
	}
	defer terraform.Destroy(t, terraformPreparation)
	terraform.InitAndApply(t, terraformPreparation)

	// Step 2: Apply the full example, assuming the provisioner roles created above.
	terraformModule := &terraform.Options{
		TerraformBinary: getHclBinary(),
		TerraformDir:    terraformDir,
		NoColor:         false,
		Lock:            true,
		BackendConfig:   backendConfig,
		Reconfigure:     true,
	}
	defer terraform.Destroy(t, terraformModule)
	terraform.InitAndApply(t, terraformModule)

	testSuccess1Output := outputClean(t, terraformModule, "test_success_1")
	assert.Equal(t, "true", testSuccess1Output, "The test_success_1 output is not true")

	testSuccess2Output := outputClean(t, terraformModule, "test_success_2")
	assert.Equal(t, "true", testSuccess2Output, "The test_success_2 output is not true")

	idcReportResult := outputMapClean(t, terraformModule, "idc_report")
	statusCode := idcReportResult["statusCode"]
	assert.Equal(t, "200", statusCode, "Expected statusCode to be 200")
}
