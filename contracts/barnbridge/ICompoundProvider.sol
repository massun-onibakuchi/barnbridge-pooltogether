// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.7.6;
pragma abicoder v2;

import "./IProvider.sol";

interface ICompoundProvider is IProvider {
    function uToken() external view;

    function cToken() external view;

    function smartYield() external view override returns (address);

    function controller() external view override returns (address);

    function underlyingFees() external view override returns (uint256);

    function setup(address smartYield_, address controller_) external;

    function setController(address newController_) external override;

    function updateAllowances() external;

    // take underlyingAmount_ from from_
    function _takeUnderlying(address from_, uint256 underlyingAmount_)
        external
        view
        override;

    // transfer away underlyingAmount_ to to_
    function _sendUnderlying(address to_, uint256 underlyingAmount_)
        external
        view
        override;

    // deposit underlyingAmount_ with the liquidity provider, callable by smartYield or controller
    function _depositProvider(uint256 underlyingAmount_, uint256 takeFees_)
        external
        override;

    // withdraw underlyingAmount_ from the liquidity provider, callable by smartYield
    function _withdrawProvider(uint256 underlyingAmount_, uint256 takeFees_)
        external
        override;

    function transferFees() external override;

    // current total underlying balance, as measured by pool, without fees
    function underlyingBalance() external override returns (uint256);

    // get exchangeRateCurrent from compound and cache it for the current block
    function exchangeRateCurrent() external returns (uint256);
}
