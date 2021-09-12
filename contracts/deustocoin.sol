// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

// TODO: adapt use of mint() and burn()

/// @title ERC20 compliant token used in the Deustocoin project for the University of Deusto
contract Deustocoin {
    string  private constant _name = "Deustocoin";
    string  private constant _symbol = "UDC";
    uint8   private constant _decimals = 2; // number of decimals the coin can be divided in, equivalent to euro in this case
    uint256 private _totalSupply = 0;  // Total supply of tokens in circulation, depends on the _mint() and _burn() calls
    address _contractOwner; // Account that deploys the contract (the project administrator, e.g. the University of Deusto)

    enum Role {Collaborator, Promoter, Administrator}

    mapping(address => uint256) balances;   // Balances of users, saved with 2 decimals (the value is equivalent to cents)
    mapping(address => mapping(address => uint256)) allowed;   // Accounts approved to withdraw from a given account + sum allowed
    mapping(address => Role) roles; // Roles of the users; access to the system is specified in the permissioned blockchain. TODO: might be expensive regarding gas

    /// @notice MUST trigger when tokens are transferred, including zero value transfers
    /// @dev a token contract which creates new tokens SHOULD trigger the event with _from set to 0x0 when tokens are created
    event Transfer(
        address indexed _from, 
        address indexed _to, 
        uint256 _value
    );

    /// @notice MUST trigger on any successful call to approve()
    event Approval(
        address indexed _owner, 
        address indexed _spender, 
        uint256 _value
    );

    /// @notice good action done by the user
    event Action(
        address indexed _who,
        uint256 indexed _actionID,
        uint256 _reward,
        uint256 _time,
        bytes32 _ipfsHash
    );


    constructor() {
        _contractOwner = msg.sender;
        balances[msg.sender] = _totalSupply;
        roles[msg.sender] = Role.Administrator;
    }

    /// @notice returns the name of the token
    /// @return token name
    function name() public pure returns (string memory) {
        return _name;
    }

    /// @notice returns the symbol of the token
    /// @return token symbol
    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    /// @notice returns the number of decimals the token uses
    /// @return token decimals
    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    /// @notice returns the total token supply
    /// @return total token supply
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /// @notice returns the account balance of the account with address _owner
    /// @return balance balance of _owner account
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    /// @notice returns the role of the account with address _owner
    /// @return role of _owner account
    function roleOf(address _owner) public view returns (string memory) {
        Role ownerRole = roles[_owner];
        if (ownerRole == Role.Collaborator) return "Collaborator";
        else if (ownerRole == Role.Promoter) return "Promoter";
        else return "Administrator";
    }

    /// @notice transfers _value amount of tokens to address _to
    /// @dev it MUST fire the Transfer event (even with value 0), and SHOULD throw if the message caller's acount doesn't have enough balance
    /// @return success of the operation
    function transfer(
        address _to, 
        uint256 _value
    ) public returns (bool success) {
        require(balances[msg.sender] >= _value);    // Must have enough balance
        require(_to != _contractOwner && _to != address(0)); // Avoid transferring to the contract owner account or the 0x00..0 account
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /// @notice transfers _value amount of tokens from address _from to address _to
    /// @dev it MUST fire the Transfer event (even with value 0), and SHOULD throw unless _from account has deliberately authorized the sender of the message via some mechanism
    /// @return success of the operation
    function transferFrom(
        address _from, 
        address _to, 
        uint256 _value
    ) public returns (bool success) {
        uint256 currentAllowance = allowed[_from][msg.sender];  // How much can be transferred
        require(balances[_from] >= _value && currentAllowance >= _value);
        balances[_to] += _value;
        balances[_from] -= _value;
        allowed[_from][msg.sender] -= _value;   // Reduce the remaining allowance
        emit Transfer(_from, _to, _value);
        return true;
    }

    /// @notice allows _spender to withdraw from your account multiple times, up to the _value amount. If called again it overwrites the current allowance with _value
    /// @return success of the operation
    function approve(
        address _spender, 
        uint256 _value
    ) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /// @notice returns the amount which _spender is allowed to withdraw from _owner
    /// @return remaining allowed withdrawal amount
    function allowance(
        address _owner, 
        address _spender
    ) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    /// @notice mints an amount of UDCs to the _to address; only an administrator can perform the operation
    /// @dev a transfer event is emitted noting that the tokens come from the 0x00...0 address
    function mint(
        address _to, 
        uint256 _value
    ) public {
        require(_to != address(0)); // Do not mint to 0x00...0
        require(roles[msg.sender] == Role.Administrator);   // Only admins can mint
        _totalSupply += _value;
        balances[_to] += _value;
        emit Transfer(address(0), _to, _value);
    }

    /// @notice burns an amount of UDCs from the _from address; only an administrator can perform the operation
    /// @dev a transfer event is emitted noting that the tokens are sent to the 0x00...0 address
    function burn(
        address _from, 
        uint256 _value
    ) public {
        require(_from != address(0));   // Do not burn from 0x00..0
        require(balances[_from] >= _value); // _from address' balance must be enough
        require(roles[msg.sender] == Role.Administrator);   // Onlye admins can burn
        _totalSupply -= _value;
        balances[_from] -= _value;
        emit Transfer(_from, address(0), _value);
    }

    /// @notice assigns a role to a given user; only an administrator can perform the operation
    function assignRole(
        address _account, 
        uint256 _role
    ) public {
        require(roles[msg.sender] == Role.Administrator);
        require(_account != _contractOwner);    // Cannot change the owner's role
        require(_role >= 0 && _role <= 2);
        if (_role == 0) roles[_account] = Role.Collaborator;
        else if (_role == 1) roles[_account] = Role.Promoter;
        else if (_role == 2) roles[_account] = Role.Administrator;
    }

    /// @notice registers a collaborator's good action in the blockchain
    function emitAction(
        address _promoter,
        address _who,
        uint256 _actionID,
        uint256 _reward,
        uint256 _time,
        bytes32 _ipfsHash
    ) public returns (bool success) {
        require(roles[msg.sender] == Role.Administrator);
        require(roles[_promoter] == Role.Promoter && roles[_who] == Role.Collaborator);
        require(balances[_promoter] >= _reward);

        emit Action(_who, _actionID, _reward, _time, _ipfsHash);
        return true;
    }
}