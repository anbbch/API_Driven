INSTANCE_ID ?= $(shell awslocal ec2 describe-instances --query "Reservations[0].Instances[0].InstanceId" --output text 2>/dev/null)
API_ID ?= $(shell awslocal apigateway get-rest-apis --query "items[0].id" --output text 2>/dev/null)
URL = http://localhost:4566/restapis/$(API_ID)/prod/_user_request_/ec2

setup:
	docker stop localstack-main 2>/dev/null || true
	docker rm localstack-main 2>/dev/null || true
	docker run -d --name localstack-main -p 4566:4566 -e SERVICES=ec2,lambda,apigateway,iam -e DEFAULT_REGION=us-east-1 -v /var/run/docker.sock:/var/run/docker.sock localstack/localstack:3.8.0
	sleep 30

deploy: setup
	aws configure set aws_access_key_id test
	aws configure set aws_secret_access_key test
	aws configure set region us-east-1
	aws configure set output json
	$(MAKE) create-infra

create-infra:
	$(eval INSTANCE_ID := $(shell awslocal ec2 run-instances --image-id ami-ff0fea8310f3 --instance-type t2.micro --count 1 --query "Instances[0].InstanceId" --output text))
	awslocal iam create-role --role-name lambda-role --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' 2>/dev/null || true
	zip function.zip lambda_function.py
	awslocal lambda create-function --function-name ec2-controller --runtime python3.11 --handler lambda_function.lambda_handler --role arn:aws:iam::000000000000:role/lambda-role --zip-file fileb://function.zip --environment Variables={INSTANCE_ID=$(INSTANCE_ID)} --timeout 30
	sleep 15
	$(eval API_ID := $(shell awslocal apigateway create-rest-api --name "EC2-Controller-API" --query "id" --output text))
	$(eval ROOT_ID := $(shell awslocal apigateway get-resources --rest-api-id $(API_ID) --query "items[0].id" --output text))
	$(eval RESOURCE_ID := $(shell awslocal apigateway create-resource --rest-api-id $(API_ID) --parent-id $(ROOT_ID) --path-part ec2 --query "id" --output text))
	awslocal apigateway put-method --rest-api-id $(API_ID) --resource-id $(RESOURCE_ID) --http-method GET --authorization-type NONE
	awslocal apigateway put-integration --rest-api-id $(API_ID) --resource-id $(RESOURCE_ID) --http-method GET --type AWS_PROXY --integration-http-method POST --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:ec2-controller/invocations
	awslocal apigateway create-deployment --rest-api-id $(API_ID) --stage-name prod
	@echo "Deploiement termine ! API_ID=$(API_ID) INSTANCE_ID=$(INSTANCE_ID)"

status:
	curl "$(URL)?action=status"

stop:
	curl "$(URL)?action=stop"

start:
	curl "$(URL)?action=start"