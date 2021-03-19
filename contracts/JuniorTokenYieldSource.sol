// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IYeildSource.sol"
import "./barnbridge/ISmartYield.sol"
import "./barnbridge/ICompoundProvider.sol"
import "./barnbridge/IProvider.sol"

contract BBCTokenYieldSource is IYeildSource,IJuniorTokenYieldSource {
    using SafeMath for uint256;

    uint256 constant EXP_SCALE = 10e18
    address public immutable syAddr;
    mapping(address => uint256) public balances;

    constructor(ISmartYield  _sy){
        // _sy.pool()
        // syAddr = address(_sy);
        pool = Controller(_sy.controller()).pool();
        pool.uToken();
        syAddr = address(_sy);
    }

    function token() public view override returns(address){
        sy = ISmartYield(syAddr);
        return ICompoundProvider(sy.pool()).uToken();
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
        ISmartYield smartYield = ISmartYield(sushiBar);
        ISushi sushi = ISushi(smartYield);

        uint256 totalShares = smartYield.totalSupply();
        uint256 barSushiBalance = sushi.balanceOf(address(smartYield));
        uint256 requiredShares =
            redeemAmount.mul(totalShares).div(barSushiBalance);

        uint256 barBeforeBalance = smartYield.balanceOf(address(this));
        uint256 sushiBeforeBalance = sushi.balanceOf(address(this));

        smartYield.leave(requiredShares);

        uint256 barAfterBalance = smartYield.balanceOf(address(this));
        uint256 sushiAfterBalance = sushi.balanceOf(address(this));

        uint256 barBalanceDiff = barBeforeBalance.sub(barAfterBalance);
        uint256 sushiBalanceDiff = sushiAfterBalance.sub(sushiBeforeBalance);

        balances[msg.sender] = balances[msg.sender].sub(barBalanceDiff);
        sushi.transfer(msg.sender, sushiBalanceDiff);
        return (sushiBalanceDiff);
    }

    function getCurrentTimestamp() internal pure returns(uint256){
        return block.timestamp
    }

}

interface IJuniorTokenYieldSource {
    event JuniorTokenYieldSourceInitialized(address indexed smartYield)
}