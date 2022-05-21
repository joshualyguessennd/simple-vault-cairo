%lang starknet
%builtins pedersen range_check


from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_nn_le, assert_le, unsigned_div_rem, assert_not_zero
from starkware.starknet.common.syscalls import storage_read, storage_write
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_eq, uint256_mul, uint256_signed_div_rem, uint256_check
)
from starkware.starknet.common.messages import send_message_to_l1
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from interfaces.cairo.interfaces import IERC20



const BUY_MESSAGE=0

@storage_var
func owner() -> (owner_address : felt):
end

@storage_var
func balances(account : felt) -> (res : Uint256):
end

@storage_var
func purchased() -> (res : felt):
end


@storage_var
func allowances(owner : felt, spender : felt) -> (res : Uint256):
end

@storage_var
func totalSupply() -> (res : Uint256):
end

@storage_var
func total_assets() -> (res : Uint256):
end


@storage_var
func total_lent() -> (res : Uint256):
end


@storage_var
func decimals() -> (res : felt):
end

@storage_var
func deposit_limit() -> (res: Uint256):
end

@storage_var
func want() -> (res : felt):
end

@storage_var
func shopAddress() -> (res : felt):
end


@storage_var
func targeted_price() -> (res : Uint256):
end



@view
func get_want{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res : felt):

    let (res) = want.read()
    return (res)

end


@view
func get_total_Asset{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res : Uint256):
    alloc_locals

    let (supply : Uint256) = totalSupply.read()
    let (lent : Uint256) = total_lent.read()
    let (res, _) = uint256_add(supply, lent)

    total_assets.write(res)    
    
    return (res)
end


@view
func get_limit{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res : Uint256):

    let (res) = deposit_limit.read()

    return (res)

end

@view
func get_decimals{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }() -> (res : felt):

    let (res) = decimals.read()
    return (res)

end

@view
func get_shop{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res : felt):
    
    let (res) = shopAddress.read()
    return (res)
end

@view
func getBalanceOf{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account_id : felt) -> (balance : Uint256):
    let (balance: Uint256) = balances.read(account=account_id)
    return (balance)
end
    



@constructor
func constructor{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (
        number : felt, 
        token : felt,
        limit : felt,
        _owner : felt,
        _price : Uint256
    ):
    decimals.write(number)
    deposit_limit.write(Uint256(limit, 0))
    owner.write(_owner)
    want.write(token)
    purchased.write(0)
    targeted_price.write(_price)
    return ()
end


@external 
func update_want{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(token : felt):
    want.write(value=token)
    return()
end


@external
func update_shop{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(shop : felt):
    shopAddress.write(value=shop)
    return ()
end


# Assert that the person calling is admin.
func only_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }() -> (_owner):
    alloc_locals
    let (local caller) = get_caller_address()
    let (_owner) = owner.read()
    assert caller = _owner
    return (_owner)
end


func not_bought{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (verified : felt):
    let (_purchased) = purchased.read()
    assert _purchased = 0
    return (1)
end


@external
func deposit{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: Uint256, token_address: felt) -> (success : felt):

    alloc_locals

    not_bought()

    let (address_contract) = get_contract_address()

    let (amountVault) = IERC20.balanceOf(token_address, address_contract)

    let (local price) = targeted_price.read()

    uint256_le(amountVault, price)

    uint256_check(amount)

    local zero: Uint256 = Uint256(0, 0)

    let (enough) = uint256_le(zero, amount)

    assert_not_zero(enough)

    # get caller address
    let (caller_address) = get_caller_address()

    let (contract_address) = get_contract_address()

    # check deposit limit of account
    let (limit: Uint256) = deposit_limit.read()
    # get total of token own by vault
    let (balanceToken: Uint256) = IERC20.balanceOf(token_address, caller_address)
    
    let (comparingValue, _ : Uint256) = uint256_add(amount, balanceToken)
    # compute deposit requirement    
    uint256_le(comparingValue, limit)

    # transfer amount from caller to contract
    IERC20.transferFrom(token_address, caller_address, contract_address, amount)

    # get the shares
    issueShares(amount)

    # mint the share for user
    _mint(caller_address, amount)
    
    return(1)
end





@external
func withdraw{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account_id: felt, shares : Uint256, token_address : felt):

    alloc_locals

    let (caller_address) = get_caller_address()

    local zero: Uint256 = Uint256(0, 0)

    let (enough_balance) = uint256_le(zero, shares)

    assert_not_zero(enough_balance)

    let  (amount: Uint256) = calc_shares(shares)

    IERC20.transfer(token_address, caller_address, amount)

    _burn(caller_address, shares)

    return ()
end

@external
func buy{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr 
    }(token: felt) -> (success : felt):
    alloc_locals
    only_owner()
    not_bought()

    let (message_payload : felt*) = alloc()
    assert message_payload[0] = BUY_MESSAGE
    let (local shop) = get_shop()
    let (local _want) = want.read()
    let (local address) = get_contract_address() 

    let (price : Uint256) = IERC20.balanceOf(token, address)

    IERC20.burn(token, address, price)
    
    send_message_to_l1(
        to_address=shop,
        payload_size=1,
        payload=message_payload,
    )

    purchased.write(1)

    return(1)
end


@view
func issueShares{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount : Uint256) -> (shares : Uint256):

    alloc_locals
    
    let (local Supply: Uint256) = totalSupply.read()

    let (local Assets: Uint256) = get_total_Asset()
    
    let zero = Uint256(0, 0)

    let (is_zero) = uint256_eq(Supply, zero)

    if is_zero == 1 :
        return (shares = amount)
    else :
        let (mul, _) = uint256_mul(Supply, amount)
        let (value, _) = uint256_signed_div_rem(mul, Assets)
        return(shares = value)
    end
    
end


func calc_shares{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(shares : Uint256) ->(amount : Uint256):

    alloc_locals

    let (local Supply: Uint256) = totalSupply.read()

    let (local Assets: Uint256) = get_total_Asset()

    let zero = Uint256(0, 0)

    let (is_zero) = uint256_le(zero, Assets)

    if is_zero == 1 :
        let (mul, _) = uint256_mul(shares, Supply)
        let (value, _) = uint256_signed_div_rem(mul, Assets)
        return (amount = value)
    else :
        return (amount = shares)
    end

end


func _mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256):
    alloc_locals
    assert_not_zero(recipient)

    let (balance: Uint256) = balances.read(account=recipient)
    # overflow is not possible because sum is guaranteed to be less than total supply
    # which we check for overflow below
    let (new_balance, _: Uint256) = uint256_add(balance, amount)
    balances.write(recipient, new_balance)

    let (local supply: Uint256) = totalSupply.read()
    let (local new_supply: Uint256, is_overflow) = uint256_add(supply, amount)
    assert (is_overflow) = 0

    totalSupply.write(new_supply)
    return ()
end

func _burn{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(sender: felt, amount: Uint256):
    alloc_locals
    assert_not_zero(sender)

    let (balance: Uint256) = balances.read(account=sender)

    let (new_balance: Uint256) = uint256_sub(balance, amount)
    
    balances.write(sender, new_balance)

    let (local supply: Uint256) = totalSupply.read()
 
    let (local new_supply: Uint256) = uint256_sub(supply, amount)

    totalSupply.write(new_supply)

    return ()
end