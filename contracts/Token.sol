// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract Token is Context, ERC20Burnable, Ownable {
    using Address for address;
    string private tokenName;
    string private tokenSymbol;
    uint8 private constant tokenDecimals = 9;
    
    uint256 private _tTotal = 100000000 * 10 ** tokenDecimals;
    uint256 private tokenTotalSupply = _tTotal;

    IUniswapV2Router02 public uniswapV2Router;
    IUniswapV2Pair public uniswapV2Pair;
    address private WETH;

    address public teamAddress;
    address public liquidityPoolAddress;
    address public liquidityPair;

    uint private burnFee = 20; //0.2% divisor 100
    uint private liquidityFee = 40; //0.4% divisor 100
    uint private teamFee = 20; //0.2% divisor 100
    uint256 public maxTxAmount = 500000 * 10**decimals();

    uint256 private slippagePercentage = 100;

    mapping(address => uint256) private _balances;
    mapping(address => bool) public feeExcludedAddress;

    
    constructor(string memory _tokenName , string memory _tokenSymbol, address routerAddress) ERC20(_tokenName, _tokenSymbol) Ownable() {
        tokenName = _tokenName;
        tokenSymbol = _tokenSymbol;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(routerAddress);
        WETH = _uniswapV2Router.WETH();
        _approve(address(this), routerAddress, tokenTotalSupply);

        address uniswapPairAddress = IUniswapV2Factory(
            _uniswapV2Router.factory()
        ).createPair(address(this), WETH);

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = IUniswapV2Pair(uniswapPairAddress);

        feeExcludedAddress[address(this)] = true;
        feeExcludedAddress[_msgSender()] = true;
        _mint(_msgSender(), tokenTotalSupply);
    }

    receive() external payable {}

    function name() public view override returns (string memory) {
        return tokenName;
    }

    function symbol() public view override returns (string memory) {
        return tokenSymbol;
    }

    function totalSupply() public view override returns (uint256) {
        return tokenTotalSupply;
    }

    function decimals() public view virtual override returns (uint8) {
        return tokenDecimals;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function calculateBurnFee(uint256 amount) internal view returns (uint256) {
        return (amount * burnFee) / (10**5);
    }

    function calculateLiquidityFee(uint256 amount) internal view returns (uint256) {
        return (amount * liquidityFee) / (10**5);
    }

    function calculateTeamFee(uint256 amount) internal view returns (uint256) {
        return (amount * teamFee) / (10**5);
    }

    function _mint(address account, uint256 amount) internal virtual override{
        require(account != address(0), "ERC20: mint to the zero address");

        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual override{
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            tokenTotalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
    }
    
    function burn(uint256 amount) public override {
         require(
            _msgSender() != address(0),
            "ERC20: burn from the dead address"
        );
        _burn(_msgSender(), amount);
    }

    function setSlippageValue(uint256 percentageAmount) external onlyOwner {
        require(
            percentageAmount > 0,
            "Slippage percentage must be greater than 0."
        );
        slippagePercentage = percentageAmount;
    }

    function addExcludedAddress(address excludedAddress) external onlyOwner{
        require(
            feeExcludedAddress[excludedAddress] == false,
            "Account is already included in Fee."
        );
        feeExcludedAddress[excludedAddress] = false;
    }
    
    function removeExcludedAddress(address excludedAddress) external onlyOwner{
        require(
            feeExcludedAddress[excludedAddress] == true,
            "Account is already excluded from Fee."
        );
        feeExcludedAddress[excludedAddress] = true;
    }

    function setLiquidityPairAddress(address liquidityPairAddress) external onlyOwner{
        liquidityPair = liquidityPairAddress;
    }
    
    function changeLPAddress(address lpAddress) external onlyOwner{
        liquidityPoolAddress = lpAddress;
    }

    function changeTeamAddress(address _teamAddress) external onlyOwner{
        teamAddress = _teamAddress;  
    }

    function setBurnFee(uint256 _burnFee) external onlyOwner{
        burnFee = _burnFee;
    }
    
    function setLiquidityFee(uint _liquidityFee) external onlyOwner{
        liquidityFee = _liquidityFee;
    }
    
    function setTeamFee(uint _teamFee) external onlyOwner{
        teamFee = _teamFee;
    }

    function setMaxTxAmount(uint256 _maxTxAmount) external onlyOwner{
        maxTxAmount = _maxTxAmount;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        if(sender != owner() && recipient != owner())
            require(amount <= maxTxAmount, "Transfer amount exceeds the maxTxAmount.");

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] = senderBalance - amount;
        uint256 tokenToTransfer = (((amount - calculateLiquidityFee(amount)) - calculateBurnFee(amount)) - calculateTeamFee(amount));

        _balances[recipient] += tokenToTransfer;
        _balances[teamAddress] += calculateTeamFee(amount); 
        _balances[address(0)] += calculateBurnFee(amount);
        _balances[liquidityPair] += calculateLiquidityFee(amount);
        
        emit Transfer(sender, recipient, tokenToTransfer);
    }

    function _transferExcluded(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        if(sender != owner() && recipient != owner())
            require(amount <= maxTxAmount, "Transfer amount exceeds the maxTxAmount.");

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] = _balances[recipient] + amount;
        
        emit Transfer(sender, recipient, amount);
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        // if(feeExcludedAddress[recipient] || feeExcludedAddress[_msgSender()]){
        if(feeExcludedAddress[recipient]){
            _transferExcluded(_msgSender(), recipient, amount);
        }else{
            _transfer(_msgSender(), recipient, amount);    
        }
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(sender, spender, amount);
        //  if(feeExcludedAddress[recipient] || feeExcludedAddress[sender]){
        if(feeExcludedAddress[recipient]){    
            _transferExcluded(sender, recipient, amount);
        }else{
            _transfer(sender, recipient, amount);
        }
        return true;
    }

    function batchTransfer(address[] memory receivers, uint256[] memory amounts) external returns(bool){
        require(receivers.length != 0, 'Cannot Proccess Null Transaction');
        require(receivers.length == amounts.length, 'Address and Amount array length must be same');
        for (uint256 i = 0; i < receivers.length; i++)
            transfer(receivers[i], amounts[i]);
        return true;    
    }

    // function addLiquidityFromContract(uint256 tokenAmount, uint256 ethAmount) external{
    //     try this.addLiquidity(tokenAmount, ethAmount) {} catch {}
    // }

    //  function swapAndLiquify(uint256 tokenAmount, uint256 ethAmount) external{
    //     try this.swapTokensForEth(tokenAmount, ethAmount) {} catch {}
    // }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) external{
        // require(msg.sender == address(this), "can only be called by the contract");
         // Add ETH liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // Min amount of token to receive
            0, // Min amount of ETH to receive
            owner(), // Address to receive LP tokens
            block.timestamp // Expiry time for the transaction
        );
    }

    function swapTokensForEth(uint256 amountIn, uint256 amountOutMin) external {
        // require(msg.sender == address(this), "can only be called by the contract");
        
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountIn,
            amountOutMin,
            path,
            address(this),
            block.timestamp
        );
    }

    function swapTokensForEth1(uint256 amountIn) external {
        
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;

        uint256 amountOutMin = getMinEthAmount(amountIn, path);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountIn,
            amountOutMin,
            path,
            address(this),
            block.timestamp
        );
    }

    function getMinEthAmount(uint256 _tokenAmount, address[] memory _path)
        private
        view
        returns (uint256)
    {
        uint256[] memory amounts = uniswapV2Router.getAmountsOut(
            _tokenAmount,
            _path
        );
        uint256 minEthAmount = (amounts[1] * slippagePercentage) / 100;
        return (amounts[1] - minEthAmount);
    }

    function getAmountsIn(uint256 amountOut) external view returns (uint256[] memory amounts) {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(this);
        amounts = uniswapV2Router.getAmountsIn(amountOut, path);
    }

     function getAmountsOut(uint256 amountIn) external view returns (uint256[] memory amounts) {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;
        amounts = uniswapV2Router.getAmountsOut(amountIn, path);
    }
}