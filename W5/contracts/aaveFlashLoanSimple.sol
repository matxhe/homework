//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/SafeMath.sol";
import "@aave/core-v3/contracts/dependencies/gnosis/contracts/GPv2SafeERC20.sol";
import "@aave/core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import "@aave/core-v3/contracts/mocks/tokens/MintableERC20.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

import '../contracts/interfaces/IUniswapV2Router01.sol';
import "../contracts/interfaces/IUniswapV2Pair.sol";
import '../contracts/interfaces/V3/ISwapRouter.sol';
import '../contracts/libraries/LowGasSafeMath.sol';

contract aaveFlashLoanSimple is FlashLoanSimpleReceiverBase {
    using GPv2SafeERC20 for IERC20;
    using SafeMath for uint256;
    uint24 MEDIUMFREE = 3000;
    address immutable routerV2;
    address immutable routerV3;
    address immutable tokenBaddr;
    address immutable myaddr;

    constructor(
        IPoolAddressesProvider provider,
        address _routerV2,
        address _routerV3,
        address _tokenBaddr,
        address _myaddr
    ) FlashLoanSimpleReceiverBase(provider) {
        routerV2 = _routerV2;
        routerV3 = _routerV3;
        tokenBaddr = _tokenBaddr;
        myaddr=_myaddr;
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address, // initiator
        bytes memory // params
    ) public override returns (bool) {
        address[] memory path = new address[](2);
        require(
            amount <= IERC20(asset).balanceOf(address(this)),
            "Invalid balance for the contract"
        );
        path[0] = asset;
        path[1] = tokenBaddr;
        IERC20 tokenA = IERC20(path[0]);
        IERC20 tokenB = IERC20(path[1]);
        uint256 amountRequired = tokenB.balanceOf(address(this));
        tokenA.approve(routerV2, amount);
        IUniswapV2Router01(routerV2).swapExactTokensForTokens(
            amount,
            0,
            path,
            address(this),
            block.timestamp
        );
        uint256 amountReceived = tokenB.balanceOf(address(this));
        assert(amountReceived > amountRequired);

        uint256 amountMin = LowGasSafeMath.add(amount, MEDIUMFREE);
        tokenB.approve(routerV3, amountReceived);
        uint256 amountOut = ISwapRouter(routerV3).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: path[1],
                tokenOut: path[0],
                fee: MEDIUMFREE,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountReceived,
                amountOutMinimum: amountMin,
                sqrtPriceLimitX96: 0
            })
        );

        assert(amountOut > amountMin);
        uint256 profit = amountOut-amount;
        assert(tokenA.transfer(myaddr, profit));

        uint256 amountToReturn = LowGasSafeMath.add(amount, premium);
        IERC20(asset).approve(address(POOL), amountToReturn);
        return true;
    }

  function testFlashLoan(address asset, uint amount) external {
    uint bal = IERC20(asset).balanceOf(address(this));
    require(bal > amount, "bal <= amount");

    address receiver = address(this);

    address[] memory assets = new address[](1);
    assets[0] = asset;

    uint[] memory amounts = new uint[](1);
    amounts[0] = amount;

    // 0 = no debt, 1 = stable, 2 = variable
    // 0 = pay all loaned
    uint[] memory modes = new uint[](1);
    modes[0] = 0;

    address onBehalfOf = address(this);

    bytes memory params = ""; // extra data to pass abi.encode(...)
    uint16 referralCode = 0;

    POOL.flashLoan(
      receiver,
      assets,
      amounts,
      modes,
      onBehalfOf,
      params,
      referralCode
    );
  }
    
}