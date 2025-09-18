package test

import (
	"log"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestIdC(t *testing.T) {
	t.Log("Starting ACF AWS IcD Module test")

	terraformIdC := &terraform.Options{
		TerraformDir: "../../examples/complete",
		NoColor:      false,
		Lock:         true,
	}

	// Initialize and apply Terraform configuration
	_, err := terraform.InitAndApplyE(t, terraformIdC)
	if err != nil {
		t.Fatalf("Failed to apply Terraform: %v", err)
	}

	testSuccess1Output := terraform.Output(t, terraformIdC, "test_success_1")
	assert.Equal(t, "true", testSuccess1Output, "The test_success_1 output is not true")

	testSuccess2Output := terraform.Output(t, terraformIdC, "test_success_2")
	assert.Equal(t, "true", testSuccess2Output, "The test_success_2 output is not true")

	idcReportResult := terraform.OutputMap(t, terraformIdC, "idc_report")
	statusCode := idcReportResult["statusCode"]
	assert.Equal(t, "200", statusCode, "Expected statusCode to be 200")

	// Try to explicitly destroy the IdC infrastructure and log error if it fails
	_, err = terraform.DestroyE(t, terraformIdC)
	if err != nil {
		log.Printf("Error during 1st Terraform destroy: %v", err)
	}

	time.Sleep(10 * time.Second) // Wait for 10 seconds before trying again

	// Ensure infrastructure is defenetly destroyed at the end of the test
	defer func() {
		if _, err := terraform.DestroyE(t, terraformIdC); err != nil {
			log.Printf("Error during Terraform destroy: %v", err)
		}
	}()
}
