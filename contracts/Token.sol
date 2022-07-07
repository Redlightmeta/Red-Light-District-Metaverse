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

    address payable public marketingWalletAddress =
        payable(0xaBd92e25550e68541Ea85DDfc3A6Fb9c046a9a22);
    address payable public teamWalletAddress =
        payable(0xa76Bbe18c0819301d63C9428c2248A086A61288d);
    address public immutable deadAddress = address(0xdead);

    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isMarketPair;

    uint256 public _buyLiquidityFee = 2;
    uint256 private constant _maxBuyLiquidityFee = 5;
    uint256 public _buyMarketingFee = 2;
    uint256 private constant _maxBuyMarketingFee = 5;
    uint256 public _buyTeamFee = 1;
    uint256 private constant _maxBuyTeamFee = 5;

    uint256 public _sellLiquidityFee = 2;
    uint256 private constant _maxSellLiquidityFee = 5;
    uint256 public _sellMarketingFee = 2;
    uint256 private constant _maxSellMarketingFee = 5;
    uint256 public _sellTeamFee = 1;
    uint256 private constant _maxSellTeamFee = 5;

    uint256 public _liquidityShare = 4;
    uint256 private constant _maxLiquidityShare = 10;
    uint256 public _marketingShare = 4;
    uint256 private constant _maxMarketingShare = 10;
    uint256 public _teamShare = 16;
    uint256 private constant _maxTeamShare = 24;

    uint256 public _totalTaxIfBuying =
        _buyLiquidityFee.add(_buyMarketingFee).add(_buyTeamFee);
    uint256 public _totalTaxIfSelling =
        _sellLiquidityFee.add(_sellMarketingFee).add(_sellTeamFee);
    uint256 public _totalDistributionShares =
        _liquidityShare.add(_marketingShare).add(_teamShare);

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapPair;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;

    event SwapAndLiquifyEnabledUpdated(bool enabled);

    event SwapAndLiquify(
        uint256 tokensForLP,
        uint256 tokensForSwap,
        uint256 amountReceived,
        uint256 totalBNBFee,
        uint256 amountBNBLiquidity,
        uint256 amountBNBTeam,
        uint256 amountBNBMarketing
    );

    event SwapTokensForETH(uint256 amountIn, address[] path);

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

        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);
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
            _allowances[_msgSender()][spender].add(addedValue)
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
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "Token: decreased allowance below zero"
            )
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
            _transfer(_msgSender(), recipients[i], amounts[i]);
        }
        return true;
    }

    function setMarketPairStatus(address account, bool newValue)
        external
        onlyOwner
    {
        isMarketPair[account] = newValue;
    }

    function setIsExcludedFromFee(address account, bool newValue)
        external
        onlyOwner
    {
        isExcludedFromFee[account] = newValue;
    }

    function setBuyTaxes(
        uint256 newLiquidityTax,
        uint256 newMarketingTax,
        uint256 newTeamTax
    ) external onlyOwner {
        require(
            newLiquidityTax <= _maxBuyLiquidityFee,
            "Token: buyLiquidityFee exceeds maximum value!"
        );
        require(
            newMarketingTax <= _maxBuyMarketingFee,
            "Token: buyMarketingFee exceeds maximum value!"
        );
        require(
            newTeamTax <= _maxBuyTeamFee,
            "Token: buyTeamFee exceeds maximum value!"
        );

        _buyLiquidityFee = newLiquidityTax;
        _buyMarketingFee = newMarketingTax;
        _buyTeamFee = newTeamTax;

        _totalTaxIfBuying = _buyLiquidityFee.add(_buyMarketingFee).add(
            _buyTeamFee
        );
    }

    function setSellTaxes(
        uint256 newLiquidityTax,
        uint256 newMarketingTax,
        uint256 newTeamTax
    ) external onlyOwner {
        require(
            newLiquidityTax <= _maxSellLiquidityFee,
            "Token: sellLiquidityFee exceeds maximum value!"
        );
        require(
            newMarketingTax <= _maxSellMarketingFee,
            "Token: sellMarketingFee exceeds maximum value!"
        );
        require(
            newTeamTax <= _maxSellTeamFee,
            "Token: sellTeamFee exceeds maximum value!"
        );

        _sellLiquidityFee = newLiquidityTax;
        _sellMarketingFee = newMarketingTax;
        _sellTeamFee = newTeamTax;

        _totalTaxIfSelling = _sellLiquidityFee.add(_sellMarketingFee).add(
            _sellTeamFee
        );
    }

    function setDistributionSettings(
        uint256 newLiquidityShare,
        uint256 newMarketingShare,
        uint256 newTeamShare
    ) external onlyOwner {
        require(
            newLiquidityShare <= _maxLiquidityShare,
            "Token: liquidityShare exceeds maximum value!"
        );
        require(
            newMarketingShare <= _maxMarketingShare,
            "Token: marketingShare exceeds maximum value!"
        );
        require(
            newTeamShare <= _maxTeamShare,
            "Token: teamShare exceeds maximum value!"
        );

        _liquidityShare = newLiquidityShare;
        _marketingShare = newMarketingShare;
        _teamShare = newTeamShare;

        _totalDistributionShares = _liquidityShare.add(_marketingShare).add(
            _teamShare
        );
    }

    function setMarketingWalletAddress(address newAddress) external onlyOwner {
        marketingWalletAddress = payable(newAddress);
    }

    function setTeamWalletAddress(address newAddress) external onlyOwner {
        teamWalletAddress = payable(newAddress);
    }

    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply.sub(balanceOf(deadAddress));
    }

    function transferToAddressETH(address payable recipient, uint256 amount)
        private
    {
        recipient.transfer(amount);
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
    }

    // to recieve ETH from uniswapV2Router when swaping
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
            _allowances[sender][_msgSender()].sub(
                amount,
                "Token: transfer amount exceeds allowance"
            )
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

            _balances[sender] = _balances[sender].sub(
                amount,
                "Token: Insufficient Balance"
            );

            uint256 finalAmount = (isExcludedFromFee[sender] ||
                isExcludedFromFee[recipient])
                ? amount
                : takeFee(sender, recipient, amount);

            _balances[recipient] = _balances[recipient].add(finalAmount);

            emit Transfer(sender, recipient, finalAmount);
            return true;
        }
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(
            amount,
            "Token: Insufficient Balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function _swapAndLiquify() private lockTheSwap {
        require(msg.sender == tx.origin, "Token: msg.sender does not match with tx.origin");

        uint256 tAmount = balanceOf(address(this));

        uint256 tokensForLP = tAmount
            .mul(_liquidityShare)
            .div(_totalDistributionShares)
            .div(2);
        uint256 tokensForSwap = tAmount.sub(tokensForLP);

        swapTokensForEth(tokensForSwap);
        uint256 amountReceived = address(this).balance;

        uint256 totalBNBFee = _totalDistributionShares.sub(
            _liquidityShare.div(2)
        );

        uint256 amountBNBLiquidity = amountReceived
            .mul(_liquidityShare)
            .div(totalBNBFee)
            .div(2);
        uint256 amountBNBTeam = amountReceived.mul(_teamShare).div(totalBNBFee);
        uint256 amountBNBMarketing = amountReceived.sub(amountBNBLiquidity).sub(
            amountBNBTeam
        );

        if (amountBNBMarketing > 0)
            transferToAddressETH(marketingWalletAddress, amountBNBMarketing);

        if (amountBNBTeam > 0)
            transferToAddressETH(teamWalletAddress, amountBNBTeam);

        if (amountBNBLiquidity > 0 && tokensForLP > 0)
            addLiquidity(tokensForLP, amountBNBLiquidity);

        emit SwapAndLiquify(
            tokensForLP,
            tokensForSwap,
            amountReceived,
            totalBNBFee,
            amountBNBLiquidity,
            amountBNBTeam,
            amountBNBMarketing
        );
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this), // The contract
            block.timestamp
        );

        emit SwapTokensForETH(tokenAmount, path);
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
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

        if (isMarketPair[sender]) {
            feeAmount = amount.mul(_totalTaxIfBuying).div(100);
        } else if (isMarketPair[recipient]) {
            feeAmount = amount.mul(_totalTaxIfSelling).div(100);
        }

        if (feeAmount > 0) {
            _balances[address(this)] = _balances[address(this)].add(feeAmount);
            emit Transfer(sender, address(this), feeAmount);
        }

        return amount.sub(feeAmount);
    }
}
