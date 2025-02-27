//SPDX-License-Identifier:MIT

pragma solidity ^0.8.25;

import {ConfirmOwner} from "chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";

contract dTSLA is ConfirmedOwner, FunctionsClient{
    using FunctionRequest for FunctionsRequest.Request;

    enum MinOrRedeem {
        mint, redeem
    }

    struct dTslaRequest{
        uint256 amountOfToken;
        address requester;
        MinOrRedeem mintOrRedeem;
    }

     address constant SEPOLIA_FUNCTIONS_ROUTER = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
     uint32 constant GAS_LIMIT = 300_000;
     bytes32 constant DON_ID = hex"66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000";
     uint64 immutable i_subId;
     string private s_mintSourceCode;
     uint256 private s_portfolioBalance;
     mapping(bytes32 requestId => dTslaRequest request) private s_requestIdToRequest;

    constructor(string memory mintSourceCode, uint64 subId) ConfirmedOwner(msg.sender) FunctionsClient(SEPOLIA_FUNCTIONS_ROUTER){
        s_mintSourceCode= mintSourceCode;
        i_subId = subId;
    }
    /// Send an HTTP request to:
    /// 1. See how much TSLA is bough
    /// 2. If enough TSLA is in the alpaca(bank) account, mint dTSLA
    /// 3. Going to be a 2 transaction function
    
    function sendMintRequest(uint256 amount) external onlyOwner returns(bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavascript(s_mintSourceCode); // This will tell our "req" object that we will be using javascript
        bytes32 requestId=_sendRequest(req.encodeCBOR(),i_subId,GAS_LIMIT,DON_ID);
        s_requestIdToRequest(requestId) = dTslaRequest(amount,msg.sender,MinOrRedeem.mint);
        return requestId;
    }

    /// Return the amount of TSLA value(in USD) is stored in our broker
    /// If we have enough TSLA token, mint the dTSLA
    function _mintFulFillRequest(bytes32 requestId, bytes memory response) internal {
        uint256 amountOfTokensToMint = s_requestIdToRequest[requestId].amountOfToken;
        
        s_portfolioBalance = uint256(bytes32(response));
    }

    /// @notice User sends a request to sell TSLA for USDC(redemptionToken)
    /// This will, have teh chainLink function call our alpaca(bank) account
    /// and do the following:
    /// 1. Sell TSLA on the brokerage
    /// 2. Buy USDC on the brokerage
    /// 3. Send USDC to this contract for the user to withdraw
    function sendRedeemRequest() external {}

    function _redeemFullFillRequest(bytes32 requestId, bytes memory response) internal {}

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory /*err*/) internal override{
        if(s_requestIdToRequest(requestid).mintOrRedeem==MinOrRedeem.mint){
            _mintFulFillRequest(requestId,response);
        } else{
            _redeemFullFillRequest(requestId,response);
        }
    }
}
