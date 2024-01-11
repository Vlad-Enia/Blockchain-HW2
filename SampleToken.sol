// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract SampleToken {
    
    string public name = "Sample Token";
    string public symbol = "TOK";

    uint256 private supply;
    
    event Transfer(address indexed _from,
                   address indexed _to,
                   uint256 _value);

    event Approval(address indexed _owner,
                   address indexed _spender,
                   uint256 _value);

    mapping (address => uint256) public balances;
    mapping (address => mapping(address => uint256)) public allowances;

    
    constructor (uint256 _initialSupply) {
        balances[msg.sender] = _initialSupply;
        supply = _initialSupply;
        emit Transfer(address(0), msg.sender, supply);
    }

    function totalSupply() public view returns(uint256) {
        return supply;
    }

    function balanceOf(address _owner) public view returns(uint256 balance) {
        return balances[_owner];
    }


    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value);

        
        balances[msg.sender] -= _value;
        balances[_to] += _value; 

        emit Transfer(msg.sender, _to, _value);

        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        
        allowances[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns(uint256 remaining) {
        return allowances[_owner][_spender];
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= balances[_from], "not enough balance");
        require(_value <= allowances[_from][msg.sender], "not enough allowance");

        
        balances[_from] -= _value;
        balances[_to] += _value;
        allowances[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }
}

contract SampleTokenSale {
    
    SampleToken public tokenContract;
    uint256 public tokenPrice;
    address owner;

    uint256 public tokensSold;

    event Sell(address indexed _buyer, uint256 indexed _amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Forbidden");
        _;
    }

    constructor(SampleToken _tokenContract, uint256 _tokenPrice) {
        owner = msg.sender;
        tokenContract = _tokenContract;
        tokenPrice = _tokenPrice;
    }

    function setTokenPrice(uint256 value) public onlyOwner() {
        require(value > 0);
        tokenPrice = value;
    }

    function buyTokens(uint256 _numberOfTokens) public payable {
        uint256 price = _numberOfTokens * tokenPrice;
        require(msg.value >= price);
        
        tokensSold += _numberOfTokens;

        if (tokenContract.balances(owner) < _numberOfTokens ||
           !tokenContract.transferFrom(owner, msg.sender, _numberOfTokens)) {

            tokensSold -= _numberOfTokens;
            revert();
        }

        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }

        emit Sell(msg.sender, _numberOfTokens);
    }

    function endSale() public {
        require(tokenContract.transfer(owner, tokenContract.balances(address(this))));
        require(msg.sender == owner);
        payable(msg.sender).transfer(address(this).balance);
    }
}

contract ProductIdentification
{
    uint public tax;
    address admin;
    mapping (uint => Product) products;
    mapping (string => bool) products_string;
    mapping (address => bool) producers;
    uint productId;

    SampleToken sampleToken;
    event debug(uint);

    struct Product
    {
        address producer;
        string name;
        uint volume;
    }

    constructor(SampleToken _sampleToken)
    {
        sampleToken = _sampleToken;
        tax = 5;
        admin = msg.sender;
        productId = 0;
    }

    modifier onlyAdmin()
    {
        require(msg.sender == admin, "Only admin");
        _;
    }

    function setTax(uint _tax) onlyAdmin() public 
    {
        tax = _tax;
    }

    function registerProducer() payable external 
    {   
        producers[msg.sender] = true;
        if (sampleToken.balanceOf(msg.sender) < tax  ||
           !sampleToken.transferFrom(msg.sender, address(this), tax)) {

            producers[msg.sender] = false;
            revert();
        }
    }

    modifier registeredProducer()
    {
        require(isProducerRegistered(msg.sender), "Must be registered producer");
        _;
    }

    function registerProduct(string calldata _name, uint _volume) registeredProducer() external 
    {
        Product memory product = Product(msg.sender, _name, _volume);
        products[productId] = product;
        products_string[_name] = true;
        productId++;
    }

    function isProducerRegistered(address _address) view public returns (bool)
    {
        return producers[_address];
    }

    function getProduct(uint id) view public returns (Product memory)
    {
        return products[id];
    }

    function productExists(uint id) view public returns (bool)
    {
        return products[id].producer != address(0);
    }

    function productExistsString(string memory name) view public returns (bool)
    {
        return products_string[name] != false;

    }

    function getProductProducer(uint _productId) view public returns (address)
    {
        return products[_productId].producer;
    }
}