# Simple vault

Here is a simple vault write in cairo, user is able to deposit and withdraw ERC20 token

# Getting started

Create a folder for your project and cd into it:
```
mkdir myproject
cd myproject
```
Create a virtualenv and activate it:

```
python3 -m venv env
source env/bin/activate
```

# compile

Compile Cairo contracts. Compilation articacts are written into the artifacts/ directory.

```
nile compile # compiles all contracts under contracts/
nile compile contracts/MyContract.cairo # compiles single contract
```

# test
run the test 

```
pytest tests/
```