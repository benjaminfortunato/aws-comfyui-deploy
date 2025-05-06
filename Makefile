all: cdk-deploy

setup: install-python install-node

install-python: venv/touchfile

venv/touchfile: requirements.txt
	@echo "Creating virtual environment..."
	python -m venv venv
	@echo "Activating venv and installing Python requirements..."
	venv/Scripts/activate && pip install -r requirements.txt
	@echo "Creating touchfile..."
	@mkdir -p venv && echo "ok" > venv/touchfile

install-node: node_modules

node_modules: package.json package-lock.json
	@echo "Installing Node.js requirements..."
	npm ci

cdk-deploy: setup
	@echo "Running cdk bootstrap..."
	npx cdk bootstrap
	@echo "Running cdk deploy..."
	npx cdk deploy

test: install-python
	venv/Scripts/activate && pytest -vv

test-update: install-python
	venv/Scripts/activate && pytest --snapshot-update

clean:
	@echo "Removing virtual environment and node modules..."
	rm -rf venv node_modules
