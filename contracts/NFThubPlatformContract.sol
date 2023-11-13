// SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFThubPlatformContract is ERC1155 {
    using Counters for Counters.Counter;
    Counters.Counter private tokenIdCounter;     // Counter for creating unique token ids
    Counters.Counter private transactionIdCounter; // Counter for creating unique transaction ids

    // Schema for an NFT
    struct NFT{
        uint256 id;
        string cid;
        address[] owners;          // Array- wallet id of all the owners of the NFT
        address creator;
        string name;
        string description;
        uint256 amount;
        string dateCreated;
        string filetype;
        string collectionId;
        uint256[] transactions;
    }

    // Schema for a Collection
    struct Collection{
        address owner;
        uint256[] nfts;        // Token id- all the NFTs of the collection
    }

    // Schema for a transaction
    struct Transaction{
        uint256 transactionId;
        address sender;
        address receiver;
        string date;
        uint256 supply;
    }

    mapping(uint256 => NFT) private nfts;                               // To store all NFTs
    mapping(string => Collection) private collections;                 // To store all Collections
    mapping(address => uint256[]) private userCollections;              // NFTs owned by a user
    mapping(uint256 => mapping(address => uint256)) public balances;    // Copies of an NFT owned by a user
    mapping(uint256 => Transaction) private transactions;               // Transaction of NFTs

    constructor() ERC1155("https://gateway.pinata.cloud/ipfs/{id}"){
    }

    // Function to create a Collection
    function createCollection(string memory _collectionId) external {
        require(collections[_collectionId].owner == address(0), "Collection already exists");

        collections[_collectionId] = Collection({
            owner: msg.sender,
            nfts: new uint256[](0)
        });
    }

    // Function to mint an NFT
    function createNFT(
        string memory _cid,
        string memory _name,
        string memory _description,
        string memory _filetype,
        uint256 _amount,
        string memory _collectionId,
        string memory _dateCreated
    )   external 
        returns (uint256 tokenId)
    {
        uint256 _transactionId = transactionIdCounter.current();
        uint256 _id = tokenIdCounter.current();
        require(collections[_collectionId].owner != address(0), "Collection doesn't exist");
        require(collections[_collectionId].owner == msg.sender, "Not the owner of the collection");

        transactions[_transactionId] = Transaction({
            transactionId: _transactionId,
            sender: address(0),
            receiver: msg.sender,
            date: _dateCreated,
            supply: _amount
        });

        nfts[_id] = NFT({
            id: _id,
            cid: _cid,
            collectionId: _collectionId,
            owners: new address[](0),
            creator: msg.sender,
            name: _name,
            description: _description,
            amount: _amount,
            filetype: _filetype,
            dateCreated: _dateCreated,
            transactions: new uint256[](0)
        });
        
        _mint(msg.sender, _id, _amount, "");
        collections[_collectionId].nfts.push(_id);            // Adding the token id in the Collection
        userCollections[msg.sender].push(_id);                // Adding the NFT in the ownership of the user
        balances[_id][msg.sender] += _amount;                 // Increasing the supply of the NFT for creator
        nfts[_id].owners.push(msg.sender);                    // Adding wallet id in the owners array of NFT
        nfts[_id].transactions.push(_transactionId);          // Adding the transaction in the array of transactions of the NFT
        transactionIdCounter.increment();
        tokenIdCounter.increment();

        return _id;
    }

    // Function to transfer an NFT
    function transferNFT(uint256 _id, address _to, uint256 _amount, string memory _date) external {
        require(balances[_id][msg.sender] >= _amount, "Insufficient NFTs to transfer");
        require(_to != address(0), "Invalid recipient address");
        require(nfts[_id].creator != address(0), "NFT doesn't exist");

        _safeTransferFrom(msg.sender, _to, _id, _amount, "");
        
        balances[_id][msg.sender] -= _amount;                 // Decreasing supply of the sender
        balances[_id][_to] += _amount;                        // Increasing supply of the receiver
        
        bool isAdded = false;
        for(uint256 i=0; i<nfts[_id].owners.length; i++){    
            if(nfts[_id].owners[i] == _to){             // Checking if user is already added as an owner
                isAdded = true;
                break;
            }
        }

        if(isAdded == false){
            nfts[_id].owners.push(_to);                  // Adding wallet id of receiver in the owners array of NFT
            userCollections[_to].push(_id);                       // Adding the NFT in the ownership of the receiver
        }

        if(balances[_id][msg.sender] == 0){                 // Works if supply of sender is 0 after transaction
            uint256 i = 0;
            uint256 indexCount=0;

            address[] memory newOwners = new address[](nfts[_id].owners.length-1);
            for(i=0; i<nfts[_id].owners.length; i++){
                if(nfts[_id].owners[i] != msg.sender){
                    newOwners[indexCount]=nfts[_id].owners[i];
                    indexCount++;
                }
            }
            nfts[_id].owners = newOwners;                  // Removing sender's id from owners array of NFT

            uint256[] memory newCollection=new uint256[](userCollections[msg.sender].length-1);
            indexCount=0;
		    for (i = 0; i<userCollections[msg.sender].length; i++){
           	    if(userCollections[msg.sender][i] != _id){
				    newCollection[indexCount]=userCollections[msg.sender][i];
				    indexCount++;
			    }
            }
		    userCollections[msg.sender]=newCollection;     // Removing NFT from the ownership of receiver
        }

        uint256 _transactionId = transactionIdCounter.current();
        transactions[_transactionId] = Transaction({       // Creating a new transaction
            transactionId: _transactionId,
            sender: msg.sender,
            receiver: _to,
            date: _date,
            supply: _amount
        });

        nfts[_id].transactions.push(_transactionId);  // Adding the transaction to the array of transactions for the nft
        transactionIdCounter.increment();
    }

    // Function to get details of an NFT
    function getNFT(uint256 _id)
        external 
        view 
        returns (
            address[] memory owners,
            address creator,
            string memory collectionId,
            string memory name,
            string memory description,
            uint256[] memory transaction,
            string memory cid,
            string memory dateCreated,
            uint256 amount
        )
    {
        require(nfts[_id].creator != address(0), "NFT doesn't exist");

        NFT memory nft = nfts[_id];
        return (
            nft.owners,
            nft.creator,
            nft.collectionId,
            nft.name,
            nft.description,
            nft.transactions,
            nft.cid,
            nft.dateCreated,
            nft.amount
        );
    }

    // Function to get details of a Collection
    function getCollection(string memory _collectionId)
        external 
        view 
        returns (
            address owner,
            uint256[] memory nft
        )
    {
        require(collections[_collectionId].owner != address(0), "Collection doesn't exist");
        Collection memory collection = collections[_collectionId];

        return (
            collection.owner,
            collection.nfts
        );
    }

    //Function to get detail of a transaction
    function getTransaction(uint256 _transactionId)
        external 
        view 
        returns (
            address sender,
            address receiver,
            string memory date,
            uint256 supply
        )
    {
        Transaction memory currentTransaction = transactions[_transactionId];
        return(
            currentTransaction.sender,
            currentTransaction.receiver,
            currentTransaction.date,
            currentTransaction.supply
        );
    }

    // Function to get supply of an NFT for a user
    function getBalance(address _owner, uint256 _id)
        external 
        view 
        returns (uint256)
    {
        return balances[_id][_owner];
    }

    // Function to get number of owners of an NFT
    function getNumberOfOwners(uint256 _id)
        external 
        view 
        returns (uint256)
    {
        return nfts[_id].owners.length;
    }

    // Function to get all the NFTs owned by a user
    function getNFTsByOwner(address _owner)
        external 
        view 
        returns(uint256[] memory)
    {
        return userCollections[_owner];
    }

    // Function to update CID of an NFT
    function updateCID(uint _id, string memory _cid) external {
        require(nfts[_id].creator != address(0), "NFTs doesn't exist");

        nfts[_id].cid = _cid;
    }
}