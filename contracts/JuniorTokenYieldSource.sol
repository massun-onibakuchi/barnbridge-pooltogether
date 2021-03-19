// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IYeildSource.sol"
import "./barnbridge/ISmartYield.sol"
import "./barnbridge/IProvider.sol"
import "./barnbridge/ComoundController.sol"

contract BBCTokenYieldSource is IYeildSource {
    using SafeMath for uint256;

    event bbcYieldSourceInitialized(address indexed smartYield);

    uint256 constant EXP_SCALE = 10e18;
    // address constant UNDERLYING_TOKEN_ADDR = 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48;
    address public immutable uTokenAddr;
    address public immutable syAddr;
    mapping(address => uint256) public balances;

    constructor(ISmartYield _sy){
        pool = CompoundController(_sy.controller()).pool();
        uTokenAddr =ICompoundProvider(pool).uToken();
        require(uTokenAddr != address(0),"INVALID_UNDELYING_TOKEN_ADDRESS");
        syAddr = address(_sy);
        emit bbcYieldSourceInitialized(syAddr)
    }

    function token() public view override returns(address){
        return uTokenAddr;
    }

    /// @notice Returns the total balance (in asset tokens).  This includes the deposits and interest.
    /// @return The underlying balance of asset tokens
    function balanceOf(address addr) public view override returns(uint256){
        ISmartYield sy = ISmartYield(syAddr);
        uint256 tokenAmount = sy.balanceOf(addr);
        // share of these tokens in the debt
        // tokenAmount * EXP_SCALE / totalSupply()
        uint256 debtShare = tokenAmount.mul(EXP_SCALE).div(sy.totalSupply());
        // (abondDebt() * debtShare) / EXP_SCALE
        uint256 forfeits = sy.abondDebt().mul(debtShare).div(EXP_SCALE);
        // debt share is forfeit, and only diff is returned to user
        // (tokenAmount * price()) / EXP_SCALE - forfeits
        return tokenAmount.mul(sy.price()).div(EXP_SCALE).sub(forfeits);
    }

    function supplyTo(uint256 amount,address to) public override {
        token().transferFrom(msg.sender, address(this), amount);
        token().approve(syAddr, amount);

        ISmartYield sy = ISmartYield(syAddr);
        uint256 beforeBalance = sy.balanceOf(address(this));

        minTokens = amount.mul(8).div(10);
        deadline = block.timestamp.add(72000) // 20*3600
        sy.buyTokens(amount, minTokens, deadline);
        uint256 afterBalance = sy.balanceOf(address(this));
        uint256 balanceDiff = afterBalance.sub(beforeBalance);
        balances[to] = balances[to].add(balanceDiff);
    }

    function redeem(uint256 amount) public override returns(uint256){
        ISmartYield sy = ISmartYield(syAddr);
        IERC20 token = IERC20(uTokenAddr);

        uint256 syBalanceBefore = sy.balanceOf(address(this));
        // uint256 syTokenBalance = token.balanceOf(address(sy));
        uint256 tokenBalanceBefore = token.balanceOf(address(this));

        deadline = block.timestamp.add(72000) // 20*3600
        sy.sellTokens(amount, 0, deadline);

        uint256 syBalanceAfter = smartYield.balanceOf(address(this));
        uint256 tokenBalanceAfter = token.balanceOf(address(this));

        uint256 syBalanceDiff = syBalanceBefore.sub(syBalanceAfter);
        uint256 tokenBalanceDiff = tokenBalanceAfter.sub(tokenBalanceBefore);

        balances[msg.sender] = balances[msg.sender].sub(syBalanceDiff);
        token.transfer(msg.sender, tokenBalanceDiff);
        return tokenBalanceDiff;
    }
}
