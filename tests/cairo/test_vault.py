import os
from _pytest.fixtures import fixture

import pytest
from starkware.starknet.testing.starknet import Starknet
from utils.Signer import Signer


CONTRACT_FILE = os.path.join("contracts/cairo", "vault.cairo")

CONTRACT_FILE_ERC20 = os.path.join("contracts/cairo", "ERC20.cairo")

CONTRACT_ACCOUNT =  os.path.join("contracts/cairo", "Account.cairo")



limit_amount = 10000000000000000000000000

def uint(a):
    return(a, 0)

@pytest.fixture(scope="function")
def amount():
    amount_a = uint(1000000000000000000000000)
    yield amount_a



def str_to_felt(text):
    b_text = bytes(text, 'UTF-8')
    return int.from_bytes(b_text, "big")

@pytest.mark.asyncio
@pytest.fixture(scope="function")
async def token(signer, starknet, amount, account):
    token = await starknet.deploy(
        CONTRACT_FILE_ERC20,
        constructor_calldata=[
            str_to_felt("Token"),      # name
            str_to_felt("TKN"),        # symbol
            *amount,               # initial_supply
            account.contract_address   # recipient
        ]
    )
    yield token



@pytest.fixture(scope="function")
@pytest.mark.asyncio
async def starknet():
    starkNet = await Starknet.empty()
    yield starkNet


@pytest.mark.asyncio
@pytest.fixture(scope="function")
async def vault(token, starknet, account, amount):
    vault = await starknet.deploy(
        CONTRACT_FILE,
        constructor_calldata=[18, token.contract_address, limit_amount, account.contract_address, *amount]
    )
    yield vault

@pytest.fixture(scope="function")
def signer():
    signer = Signer(123456789987654321)
    yield signer

@pytest.fixture(scope="function")
def signer2():
    signer2 = Signer(1234)
    yield signer2


@pytest.fixture(scope="function")
async def account2(starknet, signer2):
    account = await starknet.deploy(
        CONTRACT_ACCOUNT,
        constructor_calldata=[signer2.public_key]
    )
    yield account


@pytest.fixture(scope="function")
async def account(starknet, signer):
    account = await starknet.deploy(
        CONTRACT_ACCOUNT,
        constructor_calldata=[signer.public_key]
    )
    yield account



@pytest.mark.asyncio
async def test_vault_config(token, vault):
    decimals = await vault.get_decimals().call()
    assert decimals.result == (18, )

    want = await vault.get_want().call()
    assert want.result == (token.contract_address, )

    limit =  await vault.get_limit().call()
    assert limit.result[0][0] == limit_amount



@pytest.mark.asyncio
async def test_vault_deposit(token, signer, vault, amount, account, account2):
    balanceOfAccount = await token.balanceOf(account.contract_address).call()
    balanceVault = await token.balanceOf(vault.contract_address).call()
    assert balanceVault.result.balance == uint(0)
    assert balanceOfAccount.result.balance == amount   
    await signer.send_transaction(account, token.contract_address, 'approve', [vault.contract_address, *amount])
    deposit = await signer.send_transaction(account, vault.contract_address, 'deposit', [*amount, token.contract_address])
    balanceVaultToken = await vault.getBalanceOf(account.contract_address).call()
    assert deposit.result.response == [1]
    newBalanceAccount = await token.balanceOf(account.contract_address).call()
    assert newBalanceAccount.result.balance == uint(0)
    assert balanceVaultToken.result.balance == amount
    newBalanceVault = await token.balanceOf(vault.contract_address).call()
    assert newBalanceVault.result.balance == amount


@pytest.mark.asyncio
async def test_vault_withdraw(token, signer, vault, amount, account):
    await signer.send_transaction(account, token.contract_address, 'approve', [vault.contract_address, *amount])
    deposit = await signer.send_transaction(account, vault.contract_address, 'deposit', [*amount, token.contract_address])
    tokenVault = await token.balanceOf(vault.contract_address).call()
    assert tokenVault.result.balance == amount
    assert deposit.result.response == [1]
    balanceVaultToken = await vault.getBalanceOf(account.contract_address).call()
    assert balanceVaultToken.result.balance == amount
    tokenUser = await token.balanceOf(account.contract_address).call()
    assert tokenUser.result.balance == uint(0)
    # init withdraw
    await signer.send_transaction(account, vault.contract_address, 'withdraw', [account.contract_address, *amount, token.contract_address])
    newVaultToken = await vault.getBalanceOf(account.contract_address).call()
    newTokenVault = await token.balanceOf(vault.contract_address).call()
    newTokenUser = await token.balanceOf(account.contract_address).call()
    assert newVaultToken.result.balance == uint(0)
    assert newTokenVault.result.balance == uint(0)
    assert newTokenUser.result.balance == amount


    
    











