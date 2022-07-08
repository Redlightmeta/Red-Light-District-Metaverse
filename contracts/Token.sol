// SPDX-License-Identifier: MIT

/**
██████╗ ███████╗██████╗     ██╗     ██╗ ██████╗ ██╗  ██╗████████╗    ██████╗ ██╗███████╗████████╗██████╗ ██╗ ██████╗████████╗
██╔══██╗██╔════╝██╔══██╗    ██║     ██║██╔════╝ ██║  ██║╚══██╔══╝    ██╔══██╗██║██╔════╝╚══██╔══╝██╔══██╗██║██╔════╝╚══██╔══╝
██████╔╝█████╗  ██║  ██║    ██║     ██║██║  ███╗███████║   ██║       ██║  ██║██║███████╗   ██║   ██████╔╝██║██║        ██║   
██╔══██╗██╔══╝  ██║  ██║    ██║     ██║██║   ██║██╔══██║   ██║       ██║  ██║██║╚════██║   ██║   ██╔══██╗██║██║        ██║   
██║  ██║███████╗██████╔╝    ███████╗██║╚██████╔╝██║  ██║   ██║       ██████╔╝██║███████║   ██║   ██║  ██║██║╚██████╗   ██║   
╚═╝  ╚═╝╚══════╝╚═════╝     ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝       ╚═════╝ ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝ ╚═════╝   ╚═╝   
*/

pragma solidity 0.8.15;

// Using OpenZeppelin Implementation for security
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import {IUniswapV2Factory} from "./utils/IUniswapV2Factory.sol";
import {IUniswapV2Router01} from "./utils/IUniswapV2Router01.sol";
import {IUniswapV2Router02} from "./utils/IUniswapV2Router02.sol";

contract Token is Context, IERC20, Ownable {
    using Address for address;

    string private constant _name = "Red Light District Metaverse";
    string private constant _symbol = "RLDM";
    uint256 private constant _totalSupply = 10 * 10**9 * 10**_decimals; // 10,000,000,000
    uint8 private constant _decimals = 18;

    address public immutable deadAddress = address(0xdead);

    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isMarketPair;

    uint256 public buyTax = 5;
    uint256 public constant maxBuyTax = 5;

    uint256 public sellTax = 5;
    uint256 public constant maxSellTax = 5;

    address private constant _earlyAdoptersAddress =
        0x1182759dCEc65add7e9d892359409446Ac28CD0A;
    address private constant _privateSaleAddress =
        0x4E137eA13220EB30A8DfeC0dB9Cd6738B9C819C2;
    address private constant _publicSaleAddress =
        0xC8bd37B80A10903Eb92e3761521C5c20404180b6;
    address private constant _developmentAddress =
        0xBE02b48adAd3Fa13637DAdAaC6cBD7d3D3Ac6c4D;
    address private constant _marketingAddress =
        0x96F52552832ab1E99D25Ab72F33162381D20a086;
    address private constant _reservesAddress =
        0xA0FD44c8F06dC5A90BE71eA184777F1de5502dA4;
    address private constant _ecosystemAddress =
        0x7bB3736C8e45475211DC50B213238A514fE9Fb3a;
    address private constant _liquidityAddress =
        0x5C4a97D997a398e7764547D6a42CB9dDb683d593;
    address private constant _teamAddress =
        0x101A07374aE8c173Cb819c0d63C7200D6B7d49C7;
    address private constant _advisoryAddress =
        0x7D9869E9fbAf21b0AC0026207307CAeF60B561F3;
    address private constant _stakingAddress =
        0x9819b933dD98D19953a51616e5D6C20f338dBe6e;

    uint16 private constant _earlyAdoptersPercent = 5;
    uint16 private constant _privateSalePercent = 12;
    uint16 private constant _publicSalePercent = 30;
    uint16 private constant _developmentPercent = 6;
    uint16 private constant _marketingPercent = 7;
    uint16 private constant _reservesPercent = 5;
    uint16 private constant _ecosystemPercent = 10;
    uint16 private constant _liquidityPercent = 5;
    uint16 private constant _teamPercent = 15;
    uint16 private constant _advisoryPercent = 5;
    uint16 private constant _stakingPercent = 50;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapPair;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = false;

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiqudity
    );
    event SwapTokensForBnb(uint256 amountIn, address[] path);

    event Airdrop(address[] recipients, uint256[] amounts);
    event SetMarketPairStatus(address account, bool newValue);
    event SetIsExcludedFromFee(address account, bool newValue);
    event SetBuyTax(uint256 newValue);
    event SetSellTax(uint256 newValue);
    event ChangeRouterVersion(address newRouterAddress, address newPairAddress);

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor() {
        /**
         * @dev Routers config for PancakeSwap
         *
         * PancakeSwap v2 Mainnet Router Address: 0x10ED43C718714eb63d5aA57B78B54704E256024E
         * PancakeSwap v2 Testnet Router Address: 0xD99D1c33F9fC3444f8101754aBC46c52416550D1
         */
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );

        uniswapPair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
            address(this),
            _uniswapV2Router.WETH()
        );

        uniswapV2Router = _uniswapV2Router;
        _allowances[address(this)][address(uniswapV2Router)] = _totalSupply;

        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;

        isMarketPair[address(uniswapPair)] = true;

        uint256 stakingSupply = (_totalSupply / 100) * _stakingPercent;
        uint256 mainSupply = _totalSupply - stakingSupply;

        uint256 totalSupplyPercent = mainSupply / 100;

        // Distribution: Early Adopters
        uint256 earlyAdoptersTotal = totalSupplyPercent * _earlyAdoptersPercent;
        _balances[_earlyAdoptersAddress] = earlyAdoptersTotal;
        emit Transfer(address(0), _earlyAdoptersAddress, earlyAdoptersTotal);

        // Distribution: Private Sale
        uint256 privateSaleTotal = totalSupplyPercent * _privateSalePercent;
        _balances[_privateSaleAddress] = privateSaleTotal;
        emit Transfer(address(0), _privateSaleAddress, privateSaleTotal);

        // Distribution: Public Sale
        uint256 publicSaleTotal = totalSupplyPercent * _publicSalePercent;
        _balances[_publicSaleAddress] = publicSaleTotal;
        emit Transfer(address(0), _publicSaleAddress, publicSaleTotal);

        // Distribution: Development
        uint256 developmentTotal = totalSupplyPercent * _developmentPercent;
        _balances[_developmentAddress] = developmentTotal;
        emit Transfer(address(0), _developmentAddress, developmentTotal);

        // Distribution: Marketing
        uint256 marketingTotal = totalSupplyPercent * _marketingPercent;
        _balances[_marketingAddress] = marketingTotal;
        emit Transfer(address(0), _marketingAddress, marketingTotal);

        // Distribution: Reserves
        uint256 reservesTotal = totalSupplyPercent * _reservesPercent;
        _balances[_reservesAddress] = reservesTotal;
        emit Transfer(address(0), _reservesAddress, reservesTotal);

        // Distribution: Ecosystem
        uint256 ecosystemTotal = totalSupplyPercent * _ecosystemPercent;
        _balances[_ecosystemAddress] = ecosystemTotal;
        emit Transfer(address(0), _ecosystemAddress, ecosystemTotal);

        // Distribution: Liquidity
        uint256 liquidityTotal = totalSupplyPercent * _liquidityPercent;
        _balances[_liquidityAddress] = liquidityTotal;
        emit Transfer(address(0), _liquidityAddress, liquidityTotal);

        // Distribution: Team
        uint256 teamTotal = totalSupplyPercent * _teamPercent;
        _balances[_teamAddress] = teamTotal;
        emit Transfer(address(0), _teamAddress, teamTotal);

        // Distribution: Advisory
        uint256 advisoryTotal = totalSupplyPercent * _advisoryPercent;
        _balances[_advisoryAddress] = advisoryTotal;
        emit Transfer(address(0), _advisoryAddress, advisoryTotal);

        // Distribution: Staking
        _balances[_stakingAddress] = stakingSupply;
        emit Transfer(address(0), _stakingAddress, stakingSupply);
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            (_allowances[_msgSender()][spender] + addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            (_allowances[_msgSender()][spender] - subtractedValue)
        );
        return true;
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "Token: approve from the zero address");
        require(spender != address(0), "Token: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function airdrop(address[] calldata recipients, uint256[] calldata amounts)
        external
        onlyOwner
        returns (bool)
    {
        require(
            recipients.length == amounts.length,
            "Token: recipients and amounts must be the same length"
        );

        for (uint256 i = 0; i < recipients.length; i++) {
            _basicTransfer(_msgSender(), recipients[i], amounts[i]);
        }

        emit Airdrop(recipients, amounts);

        return true;
    }

    function setMarketPairStatus(address account, bool newValue)
        external
        onlyOwner
    {
        isMarketPair[account] = newValue;
        emit SetMarketPairStatus(account, newValue);
    }

    function setIsExcludedFromFee(address account, bool newValue)
        external
        onlyOwner
    {
        isExcludedFromFee[account] = newValue;
        emit SetIsExcludedFromFee(account, newValue);
    }

    function setBuyTax(uint256 newValue) external onlyOwner {
        require(newValue <= maxBuyTax, "Token: buyTax exceeds maximum value!");

        buyTax = newValue;

        emit SetBuyTax(buyTax);
    }

    function setSellTax(uint256 newValue) external onlyOwner {
        require(
            newValue <= maxSellTax,
            "Token: sellTax exceeds maximum value!"
        );

        sellTax = newValue;

        emit SetSellTax(sellTax);
    }

    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply - balanceOf(deadAddress);
    }

    function transferToAddressETH(address payable recipient, uint256 amount)
        private
    {
        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Token: unable to send value, recipient may have reverted"
        );
    }

    function changeRouterVersion(address newRouterAddress)
        external
        onlyOwner
        returns (address newPairAddress)
    {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            newRouterAddress
        );

        newPairAddress = IUniswapV2Factory(_uniswapV2Router.factory()).getPair(
            address(this),
            _uniswapV2Router.WETH()
        );

        if (newPairAddress == address(0)) {
            //Create If Doesnt exist
            newPairAddress = IUniswapV2Factory(_uniswapV2Router.factory())
                .createPair(address(this), _uniswapV2Router.WETH());
        }

        uniswapPair = newPairAddress; //Set new pair address
        uniswapV2Router = _uniswapV2Router; //Set new router address

        isMarketPair[address(uniswapPair)] = true;

        emit ChangeRouterVersion(newRouterAddress, newPairAddress);
    }

    // to recieve BNB from uniswapV2Router when swaping
    receive() external payable {}

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            (_allowances[sender][_msgSender()] - amount)
        );
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private returns (bool) {
        require(sender != address(0), "Token: transfer from the zero address");
        require(recipient != address(0), "Token: transfer to the zero address");

        if (inSwapAndLiquify) {
            return _basicTransfer(sender, recipient, amount);
        } else {
            if (
                !inSwapAndLiquify &&
                !isMarketPair[sender] &&
                swapAndLiquifyEnabled
            ) {
                _swapAndLiquify();
            }

            _balances[sender] = _balances[sender] - amount;

            uint256 finalAmount = (isExcludedFromFee[sender] ||
                isExcludedFromFee[recipient])
                ? amount
                : takeFee(sender, recipient, amount);

            _balances[recipient] = _balances[recipient] + finalAmount;

            emit Transfer(sender, recipient, finalAmount);
            return true;
        }
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function _swapAndLiquify() private lockTheSwap {
        require(
            msg.sender == tx.origin,
            "Token: msg.sender does not match with tx.origin"
        );

        uint256 tAmount = balanceOf(address(this));
        if (tAmount > 0) {
            // split the contract balance into halves
            uint256 half = tAmount / 2;
            uint256 otherHalf = tAmount - half;

            // capture the contract's current BNB balance.
            // this is so that we can capture exactly the amount of BNB that the
            // swap creates, and not make the liquidity event include any BNB that
            // has been manually sent to the contract
            uint256 initialBalance = address(this).balance;

            // swap tokens for BNB
            _swapTokensForBnb(half); // <- this breaks the BNB -> RLDM swap when swap+liquify is triggered

            // how much BNB did we just swap into?
            uint256 newBalance = address(this).balance - initialBalance;

            // add liquidity to uniswap
            _addLiquidity(otherHalf, newBalance);

            emit SwapAndLiquify(half, newBalance, otherHalf);
        }
    }

    function _swapTokensForBnb(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> wbnb
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BNB
            path,
            address(this), // The contract
            block.timestamp
        );

        emit SwapTokensForBnb(tokenAmount, path);
    }

    function _addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }

    function takeFee(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (uint256) {
        uint256 feeAmount = 0;

        if (buyTax > 0 && isMarketPair[sender]) {
            feeAmount = (amount * buyTax) / 100;
        } else if (sellTax > 0 && isMarketPair[recipient]) {
            feeAmount = (amount * sellTax) / 100;
        }

        if (feeAmount > 0) {
            _balances[address(this)] = _balances[address(this)] + feeAmount;
            emit Transfer(sender, address(this), feeAmount);
        }

        return amount - feeAmount;
    }
}
