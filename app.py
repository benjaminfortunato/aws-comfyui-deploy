#!/usr/bin/env python3
import os
import aws_cdk as cdk
from aws_cdk import Environment
from aws_cdk import Aspects
from comfyui_aws_stack.comfyui_aws_stack import ComfyUIStack
from cdk_nag import AwsSolutionsChecks, NagSuppressions

app = cdk.App()
comfy_ui_stack = ComfyUIStack(
    app, "ComfyUIStack",
    description="ComfyUI on AWS (uksb-ggn3251wsp)",
    env=Environment(
        account=os.environ["CDK_DEFAULT_ACCOUNT"],
        region=os.environ["CDK_DEFAULT_REGION"]
    ),
    tags={
        "Repository": "aws-samples/cost-effective-aws-deployment-of-comfyui"
    },    # Disable Cognito authentication as it's causing deployment issues
    # and not needed for team-only access
    self_sign_up_enabled=False,
    saml_auth_enabled=False,
    mfa_required=False,
    # For security, since we've disabled Cognito authentication, we're restricting access by IP
    # You can add multiple IPs using the format: ["1.2.3.4/32", "5.6.7.8/32"]
    allowed_ip_v4_address_ranges=["72.80.157.72/32"],  # This allows all IPs - REPLACE with your specific IP
    # Override Parameters (example)
    # auto_scale_down=False,
    # schedule_auto_scaling=True,
    # timezone="Asia/Tokyo",
    # schedule_scale_up="0 8 * * 1-5",
    # schedule_scale_down="0 19 * * *",
    # allowed_sign_up_email_domains=["amazon.com"],
    cheap_vpc=False,
    use_spot=False
)

Aspects.of(app).add(AwsSolutionsChecks(verbose=False))
NagSuppressions.add_stack_suppressions(stack=comfy_ui_stack, suppressions=[
    {"id": "AwsSolutions-L1", "reason": "Lambda Runtime is provided by custom resource provider and drain ecs hook implicitely and not critical for sample"},
    {"id": "AwsSolutions-IAM4",
        "reason": "For sample purposes the managed policy is sufficient"},
    {"id": "AwsSolutions-IAM5",
        "reason": "Some rules require '*' wildcard as an example ACM operations, and other are sufficient for Sample"},
    {"id": "CdkNagValidationFailure", "reason": "Suppressions for cdk nag"},
])

app.synth()

