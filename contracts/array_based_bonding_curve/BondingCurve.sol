// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";

contract BondingCurve {
    struct Step {
        uint256 supply;
        uint256 price;
    }

    function getCost(Step[] memory steps, uint256 supply, uint256 amount) public pure returns (uint256) {
        uint256 cost = 0;
        
        for (uint256 i = 0; i < steps.length; i++) {
            if (supply >= steps[i].supply) {
                continue;
            }
            
            uint256 stepSupply = (i == steps.length - 1) ? type(uint256).max : steps[i].supply;
            uint256 availableInStep = stepSupply - supply;
            uint256 purchaseInStep = Math.min(amount, availableInStep);
            
            cost += purchaseInStep * steps[i].price;
            amount -= purchaseInStep;
            supply += purchaseInStep;
            
            if (amount == 0) break;
        }
        
        require(amount == 0, "Not enough supply in bonding curve");
        return cost;
    }

    function getRefund(Step[] memory steps, uint256 supply, uint256 amount) public pure returns (uint256) {
        uint256 remainingAmount = amount;
        uint256 refund = 0;
        uint256 currentSupply = supply;
        
        require(supply >= amount, "Not enough tokens to sell");
        
        for (uint256 i = 0; i < steps.length; i++) {
            uint256 stepLowerBound = i > 0 ? steps[i-1].supply : 0;
            
            if (currentSupply <= stepLowerBound) continue;
            
            uint256 tokensInStep = currentSupply - stepLowerBound;
            uint256 saleInStep = remainingAmount > tokensInStep ? tokensInStep : remainingAmount;
            
            refund += saleInStep * steps[i].price;
            remainingAmount -= saleInStep;
            currentSupply -= saleInStep;
            
            if (remainingAmount == 0) break;
        }
        
        require(remainingAmount == 0, "Refund calculation failed");
        return refund;
    }

    function getCurrentPrice(Step[] memory steps, uint256 supply) public pure returns (uint256) {
        for (uint256 i = 0; i < steps.length; i++) {
            if (supply < steps[i].supply) {
                return steps[i].price;
            }
        }
        return steps[steps.length - 1].price;
    }
}