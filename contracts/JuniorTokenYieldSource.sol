// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IYeildSource.sol"
import "./barnbridge/ISmartYield.sol"
import "./barnbridge/IProvider.sol"
import "./barnbridge/ComoundController.sol"

contract BBCTokenYieldSource is IYeildSource,IJuniorTokenYieldSource {
    using SafeMath for uint256;

    uint256 constant EXP_SCALE = 10e18
    address constant UNDERLYING_TOKEN_ADDR = 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
    address public immutable uTokenAddr;
    address public immutable syAddr;
    mapping(address => uint256) public balances;

    constructor(ISmartYield _sy){
        pool = CompoundController(_sy.controller()).pool();
        uTokenAddr =ICompoundProvider(pool).utoken();
        syAddr = address(_sy);
    }

    function token() public view override returns(address){
        return uTokenAddr;
    }

    /// @notice Returns the total balance (in asset tokens).  This includes the deposits and interest.
    /// @return The underlying balance of asset tokens
    function balanceOf(address addr) external view override returns(uint256){
        ISmartYield sy = ISmartYield(syAddr);
        uint256 tokenAmount = sy.balanceOf(addr);
        // share of these tokens in the debt
        // tokenAmount * EXP_SCALE / totalSupply()
        uint256 debtShare = tokenAmount.mul(EXP_SCALE).div(sy.totalSupply());
        // (abondDebt() * debtShare) / EXP_SCALE
        uint256 forfeits = abondDebt().mul(debtShare).div(EXP_SCALE);
        // debt share is forfeit, and only diff is returned to user
        // (tokenAmount * price()) / EXP_SCALE - forfeits
        return tokenAmount.mul(sy.price()).div(EXP_SCALE).sub(forfeits);
    }

    function supplyTo(uint256 amount,address to) external override {
        token().transferFrom(msg.sender, address(this), amount);
        token().approve(smartYield, amount);

        ISmartYield smartYield = ISmartYield(syAddr);
        uint256 beforeBalance = smartYield.balanceOf(address(this));

        minTokens = amount.mul(8).div(10);
        deadline = getCurrentTimestamp().add(54000) // 15*3600
        smartYield.buyTokens(amount,minTokens,deadline);
        uint256 afterBalance = smartYield.balanceOf(address(this));
        uint256 balanceDiff = afterBalance.sub(beforeBalance);
        balances[to] = balances[to].add(balanceDiff);
    }

    function redeem(uint256 amount) external override returns(uint256){
        ISmartYield sy = ISmartYield(syAddr);
        IERC20 token = IERC20(UNDERLYING_TOKEN_ADDR);

        uint256 totalShares = sy.totalSupply();
        uint256 syTokenBalance = token.balanceOf(address(sy));
        uint256 requiredShares = amount.mul(totalShares).div(syTokenBalance);

        uint256 syBeforeBalance = sy.balanceOf(address(this));
        uint256 tokenBeforeBalance = token.balanceOf(address(this));

        sy.leave(requiredShares);

        uint256 syAfterBalance = sy.balanceOf(address(this));
        uint256 tokenAfterBalance = token.balanceOf(address(this));

        uint256 syBalanceDiff = syBeforeBalance.sub(syAfterBalance);
        uint256 tokenBalanceDiff = tokenAfterBalance.sub(tokenBeforeBalance);

        balances[msg.sender] = balances[msg.sender].sub(syBalanceDiff);
        sushi.transfer(msg.sender, tokenBalanceDiff);
        return tokenBalanceDiff;
    }

    function getCurrentTimestamp() internal pure returns(uint256){
        return block.timestamp
    }

}

interface IJuniorTokenYieldSource {
    event JuniorTokenYieldSourceInitialized(address indexed smartYield)
}