// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.7.6;

interface IController {
    function pool() external view returns (address);

    function smartYield() external view returns (address);

    function oracle() external view returns (address);
}
