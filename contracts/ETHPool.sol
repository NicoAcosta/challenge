//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// struct LPData {
//     uint256 timestap;
//     uint256 balance;
// }

contract ETHPool is ERC721, Ownable, AccessControl {
    using Counters for Counters.Counter;

    event AddLiquidity(
        address indexed provider,
        uint256 indexed tokenId,
        uint256 ethProvided
    );
    event Withdrawal(
        uint256 indexed tokenId,
        address indexed recipient,
        uint256 ethWithdrawn
    );
    event Reward(uint256 indexed tokenId, uint256 ethRewarded);

    event RewardDeposit(address indexed teamMember, uint256 amount);

    Counters.Counter private _tokenIds;
    bytes32 public constant TEAM_MEMBER = keccak256("TEAM_MEMBER");
    uint256 public lastRewardTimestamp = 0;

    // mapping(uint256 => LPData) data;
    mapping(uint256 => uint256) public deposits;
    mapping(uint256 => uint256) public rewards;
    mapping(uint256 => uint256) public timestamps;

    constructor() ERC721("ETHPool", "ETHP") {
        _setupRole(TEAM_MEMBER, msg.sender);
    }

    //
    //  TEAM MEMBER ROLE
    //

    function isTeamMember(address _teamMember) external view returns (bool) {
        return hasRole(TEAM_MEMBER, _teamMember);
    }

    function amTeamMember() external view returns (bool) {
        return hasRole(TEAM_MEMBER, msg.sender);
    }

    function addTeamMember(address _newTeamMember) external onlyOwner {
        _setupRole(TEAM_MEMBER, _newTeamMember);
    }

    function removeTeamMember(address _teamMember) external onlyOwner {
        _revokeRole(TEAM_MEMBER, _teamMember);
    }

    //
    //
    //

    function balanceOfToken(uint256 _tokenId) public view returns (uint256) {
        require(_exists(_tokenId));
        return deposits[_tokenId] + rewards[_tokenId];
    }

    function addLiquidity() external payable returns (uint256) {
        require(msg.value > 0, "Invalid ETH amount");

        uint256 _newTokenId = _nextId();

        // data[_newTokenId] = LPData(block.timestamp, msg.value);
        deposits[_newTokenId] = msg.value;
        rewards[_newTokenId] = 0;
        timestamps[_newTokenId] = block.timestamp;

        _mint(msg.sender, _newTokenId);

        emit AddLiquidity(msg.sender, _newTokenId, msg.value);

        return _newTokenId;
    }

    function _nextId() private returns (uint256) {
        _tokenIds.increment();
        return _tokenIds.current();
    }

    function depositRewards() external payable onlyRole(TEAM_MEMBER) {
        require(_tokenIds.current() > 0, "No deposits yet");
        require(msg.value > 0, "Invalid token amount");

        uint256 _totalPoints = 0;
        uint256 _tokensAmount = _tokenIds.current();

        if (lastRewardTimestamp == 0) {
            // initial rewards

            for (uint256 _tokenId = 1; _tokenId <= _tokensAmount; _tokenId++) {
                if (_exists(_tokenId)) {
                    _totalPoints += _initialRewardPoints(_tokenId);
                }
            }

            for (uint256 _tokenId = 1; _tokenId <= _tokensAmount; _tokenId++) {
                if (_exists(_tokenId)) {
                    _addReward(
                        _tokenId,
                        _initialRewardPoints(_tokenId),
                        _totalPoints
                    );
                }
            }
        } else {
            // rewards after initial reward

            for (uint256 _tokenId = 1; _tokenId <= _tokensAmount; _tokenId++) {
                if (_exists(_tokenId)) {
                    _totalPoints += _rewardPoints(_tokenId);
                }
            }

            for (uint256 _tokenId = 1; _tokenId <= _tokensAmount; _tokenId++) {
                if (_exists(_tokenId)) {
                    _addReward(_tokenId, _rewardPoints(_tokenId), _totalPoints);
                }
            }
        }

        lastRewardTimestamp = block.timestamp;

        emit RewardDeposit(msg.sender, msg.value);
    }

    function _initialRewardPoints(uint256 _tokenId)
        private
        view
        returns (uint256)
    {
        return deposits[_tokenId] * (block.timestamp - timestamps[_tokenId]);
    }

    function _rewardPoints(uint256 _tokenId) private view returns (uint256) {
        uint256 _depositTimestamp = timestamps[_tokenId];
        uint256 _initialTimestamp = _depositTimestamp > lastRewardTimestamp
            ? _depositTimestamp
            : lastRewardTimestamp;

        return balanceOfToken(_tokenId) * (block.timestamp - _initialTimestamp);
    }

    function _addReward(
        uint256 _tokenId,
        uint256 _tokenPoints,
        uint256 _totalPoints
    ) private {
        uint256 _tokenReward = (_tokenPoints * msg.value) / _totalPoints;

        rewards[_tokenId] += _tokenReward;
        emit Reward(_tokenId, _tokenReward);
    }

    //
    //
    //

    function withdraw(uint256 _tokenId) external returns (uint256) {
        address _owner = ownerOf(_tokenId);
        require(_owner == msg.sender, "Caller is not token owner");
        uint256 _amount = balanceOfToken(_tokenId);

        _burn(_tokenId);
        payable(_owner).transfer(_amount);

        emit Withdrawal(_tokenId, _owner, _amount);

        return _amount;
    }

    //
    //
    //

    function exists(uint256 _tokenId) external view returns (bool) {
        return _exists(_tokenId);
    }

    function tokensAmount() external view returns (uint256) {
        return _tokenIds.current();
    }

    function activeTokens() external view returns (uint256) {
        uint256 _active = 0;
        for (
            uint256 _tokenId = 1;
            _tokenId <= _tokenIds.current();
            _tokenId++
        ) {
            if (_exists(_tokenId)) {
                _active += 1;
            }
        }
        return _active;
    }

    function currentStacked() external view returns (uint256) {
        uint256 _stacked = 0;
        for (
            uint256 _tokenId = 1;
            _tokenId <= _tokenIds.current();
            _tokenId++
        ) {
            if (_exists(_tokenId)) {
                _stacked += balanceOfToken(_tokenId);
            }
        }
        return _stacked;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl)
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
