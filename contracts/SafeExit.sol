// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Enum {
    enum Operation {
        Call,
        DelegateCall
    }
}

interface Executor {
    /// @dev Allows a Module to execute a transaction.
    /// @param to Destination address of module transaction.
    /// @param value Ether value of module transaction.
    /// @param data Data payload of module transaction.
    /// @param operation Operation type of module transaction.
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) external returns (bool success);
}

contract SafeExit {
    Executor public executor;
    ERC20 public designatedToken;
    uint256 public circulatingSupply;

    event SafeExitModuleSetup(address indexed initiator, address indexed safe);
    event ExitSuccessful(address leaver);

    /// @notice Mapping of denied tokens defined by the executor
    mapping(address => bool) public deniedTokens;

    modifier executorOnly() {
        require(msg.sender == address(executor), "Not authorized");
        _;
    }

    constructor(
        Executor _executor,
        address _designatedToken,
        uint256 _circulatingSupply
    ) {
        setUp(_executor, _designatedToken, _circulatingSupply);
    }

    /// @dev Initialize function, will be triggered when a new proxy is deployed
    /// @param _executor Address of the executor (e.g. a Safe)
    /// @param _designatedToken Address of the ERC20 token that will define the share of users
    /// @param _circulatingSupply Circulating Supply of designated token
    /// @notice Designated token address can not be zero
    function setUp(
        Executor _executor,
        address _designatedToken,
        uint256 _circulatingSupply
    ) public {
        require(
            address(executor) == address(0),
            "Module is already initialized"
        );
        require(
            _designatedToken != address(0),
            "Designated token can not be zero"
        );
        executor = _executor;
        designatedToken = ERC20(_designatedToken);
        circulatingSupply = _circulatingSupply;

        emit SafeExitModuleSetup(msg.sender, address(_executor));
    }

    /// @dev Execute the share of assets and the transfer of designated tokens
    /// @param tokens Array of tokens that the leaver will recieve
    /// @notice will throw if a token sent is added in the denied token list
    function exit(uint256 amountToBurn, address[] calldata tokens) public {
        // 0x23b872dd - bytes4(keccak256("transferFrom(address,address,uint256)"))
        bytes memory data = abi.encodeWithSelector(
            0x23b872dd,
            msg.sender,
            address(executor),
            amountToBurn
        );

        require(
            executor.execTransactionFromModule(
                address(designatedToken),
                0,
                data,
                Enum.Operation.Call
            ),
            "Error on exit execution"
        );

        for (uint8 i = 0; i < tokens.length; i++) {
            require(!deniedTokens[tokens[i]], "Invalid token");
            transferToken(tokens[i], msg.sender, amountToBurn);
        }

        emit ExitSuccessful(msg.sender);
    }

    /// @dev Execute a token transfer through the executor
    /// @param token address of token to transfer
    /// @param leaver address that will receive the transfer
    function transferToken(
        address token,
        address leaver,
        uint256 amountToBurn
    ) private {
        uint256 ownerBalance = ERC20(token).balanceOf(address(executor));
        uint256 supply = getCirculatingSupply();
        uint256 amount = (amountToBurn * ownerBalance) / supply;
        // 0xa9059cbb - bytes4(keccak256("transfer(address,uint256)"))
        bytes memory data = abi.encodeWithSelector(0xa9059cbb, leaver, amount);
        require(
            executor.execTransactionFromModule(
                token,
                0,
                data,
                Enum.Operation.Call
            ),
            "Error on token transfer"
        );
    }

    /// @dev Add a batch of token addresses to denied tokens list
    /// @param tokens Batch of addresses to add into the denied token list
    /// @notice Can not add duplicate token address or it will throw
    function addToDenylist(address[] calldata tokens) external executorOnly {
        for (uint8 i; i < tokens.length; i++) {
            require(!deniedTokens[tokens[i]], "Token already denied");
            deniedTokens[tokens[i]] = true;
        }
    }

    /// @dev Remove a batch of token addresses from denied tokens list
    /// @param tokens Batch of addresses to be removed from the denied token list
    /// @notice If a non denied token address is passed, the function will throw
    function removeFromDenylist(address[] calldata tokens)
        external
        executorOnly
    {
        for (uint8 i; i < tokens.length; i++) {
            require(deniedTokens[tokens[i]], "Token not denied");
            deniedTokens[tokens[i]] = false;
        }
    }

    /// @dev Change the designated token address variable
    /// @param _token Address of new designated token
    /// @notice Can only be modified by executor
    function setDesignatedToken(address _token) public executorOnly {
        designatedToken = ERC20(_token);
    }

    function setCirculatingSupply(uint256 _circulatingSupply)
        external
        executorOnly
    {
        circulatingSupply = _circulatingSupply;
    }

    function getCirculatingSupply() public view returns (uint256) {
        return circulatingSupply;
    }
}
