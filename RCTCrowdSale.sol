pragma solidity ^0.4.10;

contract CarefulOperation {
    // add 
    function checkAdd(uint256 x, uint256 y) internal returns(uint256) {
        uint256 z = x + y;
        assert((z >= x) && (z >= y));
        return z;
    }
    // substract
    function checkSubtract(uint256 x, uint256 y) internal returns(uint256) {
        assert(x >= y);
        uint256 z = x - y;
        return z;
    }

    // multiply
    function checkMultiply(uint256 x, uint256 y) internal returns(uint256) {
        uint256 z = x * y;
        assert((x == 0)||(z/x == y));
        return z;
    }
}

/*  ERC 20 token */
contract StandardToken {
    /* init an array with balances */
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    mapping (address => bool) public blacklisted;
    
    /* events */
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    /* functions */
    function transfer(address _to, uint256 _value) returns (bool success) {
        if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        } else {
            return false;
        }
    }
    
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
            balances[_to] += _value;
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            Transfer(_from, _to, _value);
            return true;
        } else {
            return false;
        }
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
}

/* RCT token */
contract RCToken is StandardToken, CarefulOperation {
    /* varibles of RCT token */
    string public constant name = "RCToken";
    string public constant symbol = "RCT";
    uint256 public constant decimals = 18;
    uint256 public icoSupplied = 0;
    string public version = "1.0";

    address public ethFundDeposit;
    address public rctFundDeposit;

    bool public isFinished;
    uint256 public fundingStartBlock;
    uint256 public fundingEndBlock;
    uint256 public constant rctFund = 0.3 * 420 * (10**6) * 10**decimals;
    uint256 public constant icoCap =  0.4 * 420 * (10**6) * 10**decimals;
    uint256 public tokenLeft;

    /* events */
    event CreateRCT(address indexed _to, uint256 _value);

    /* functions */
    function RCToken(
        address _ethFundDeposit,
        address _rctFundDeposit,
        uint256 _fundingStartBlock,
        uint256 _fundingEndBlock)
    {
        isFinished = false;
        ethFundDeposit = _ethFundDeposit;
        rctFundDeposit = _rctFundDeposit;
        fundingStartBlock = _fundingStartBlock;
        fundingEndBlock = _fundingEndBlock;
        balances[rctFundDeposit] = rctFund;
        CreateRCT(rctFundDeposit, rctFund);
    }

    function tokenRate() constant returns(uint) {
        if (block.number>=fundingStartBlock && block.number<fundingStartBlock+100) return 200; // evern early
        if (block.number>=fundingStartBlock && block.number<fundingStartBlock+200) return 170; // early bird
        return 130;                                                                            // regular
    }

    function makeTokens() payable  {
        require (!isFinished);
        require (block.number >= fundingStartBlock);
        require (block.number <= fundingEndBlock);
        require (msg.value != 0);
        
        if (block.number>=fundingStartBlock && block.number<fundingStartBlock+100) {
            require (!blacklisted[msg.sender]);
        }
        

        uint256 tokens = checkMultiply(msg.value, tokenRate());
        uint256 tokenOffered = checkAdd(icoSupplied, tokens);
        tokenLeft = checkSubtract(icoCap, tokenOffered);

        require (icoCap >= tokenOffered);

        icoSupplied = tokenOffered;
        balances[msg.sender] += tokens;
        CreateRCT(msg.sender, tokens);
    }

    function() payable {
        makeTokens();
        if (block.number>=fundingStartBlock && block.number<fundingStartBlock+100) {
            blacklisted[msg.sender] = true; 
        }
    }

    function finalize() external {
        require (!isFinished);
        require (msg.sender == ethFundDeposit);
        require (block.number > fundingEndBlock || icoSupplied == icoCap);

        isFinished = true;
        require(ethFundDeposit.send(this.balance));
        balances[rctFundDeposit] += tokenLeft;
    }
}
