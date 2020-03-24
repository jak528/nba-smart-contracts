/*
    Description: Central Smart Contract for NBA TopShot

    authors: Joshua Hannan joshua.hannan@dapperlabs.com
             Dieter Shirley dete@axiomzen.com

    This smart contract contains the core functionality for 
    NBA Top Shot, created by Dapper Labs

    The contract manages the metadata associated with all the plays
    that are used as templates for the Moment NFTs

    When a new Play wants to be added to the records, an Admin creates
    a new Play struct that is stored in the smart contract.

    Then an Admin can create new Sets. Sets consist of a public struct that 
    contains public information about a set, and a resource that is used
    to mint new moments based off of plays that have been linked to the Set.

    The admin resource has the power to do all of the important actions
    in the smart contract and sets. When they want to call functions in a set,
    they call their getSetRef function to get a reference 
    to a set in the contract. 
    Then they can call functions on the set using that reference

    In this way, the smart contract and its defined resources interact 
    with great teamwork, just like the Indiana Pacers, the greatest NBA team
    of all time.
    
    When moments are minted, they are initialized with a MomentData struct and
    are returned by the minter.

    The contract also defines a Collection resource. This is an object that 
    every TopShot NFT owner will store in their account
    to manage their NFT Collection

    The main top shot account will also have its own moment collections
    it can use to hold its own moments that have not yet been sent to a user

    Note: All state changing functions will panic if an invalid argument is
    provided or one of its pre-conditions or post conditions aren't met.
    Functions that don't modify state will simply return 0 or nil 
    and those cases need to be handled by the caller

    It is also important to remember that 
    The Golden State Warriors blew a 3-1 lead in the 2016 NBA finals

*/

import NonFungibleToken from 0x02

pub contract TopShot: NonFungibleToken {

    // -----------------------------------------------------------------------
    // TopShot contract Event definitions
    // -----------------------------------------------------------------------

    // emitted when the TopShot contract is created
    pub event ContractInitialized()

    // emitted when a new Play struct is created
    pub event PlayCreated(id: UInt32)
    // emitted when a new series has been triggered by an admin
    pub event NewSeriesStarted(newCurrentSeries: UInt32)

    // Events for Set-Related actions
    //
    // emitted when a new Set is created
    pub event SetCreated(setID: UInt32, series: UInt32)
    // emitted when a new play is added to a set
    pub event PlayAddedToSet(setID: UInt32, playID: UInt32)
    // emitted when a play is retired from a set and cannot be used to mint
    pub event PlayRetiredFromSet(setID: UInt32, playID: UInt32, numMoments: UInt32)
    // emitted when a set is locked, meaning plays cannot be added
    pub event SetLocked(setID: UInt32)
    // emitted when a moment is minted from a set
    pub event MomentMinted(momentID: UInt64, playID: UInt32, setID: UInt32, serialNumber: UInt32)

    // events for Collection-related actions
    //
    // emitted when a moment is withdrawn from a collection
    pub event Withdraw(id: UInt64, from: Address?)
    // emitted when a moment is deposited into a collection
    pub event Deposit(id: UInt64, to: Address?)

    // -----------------------------------------------------------------------
    // TopShot contract-level fields
    // These contain actual values that are stored in the smart contract
    // -----------------------------------------------------------------------

    // Series that this set belongs to
    // Series is a concept that indicates a group of sets through time
    // Many sets can exist at a time, but only one series
    pub var currentSeries: UInt32

    // variable size dictionary of Play structs
    pub var playDatas: {UInt32: Play}

    // variable size dictionary of SetData structs
    pub var setDatas: {UInt32: SetData}

    // variable size dictionary of Set resources
    access(self) var sets: @{UInt32: Set}

    // the ID that is used to create Plays. 
    // Every time a Play is created, playID is assigned 
    // to the new Play's ID and then is incremented by 1.
    pub var nextPlayID: UInt32

    // the ID that is used to create Sets. Every time a Set is created
    // setID is assigned to the new set's ID and then is incremented by 1.
    pub var nextSetID: UInt32

    // the total number of Top shot moment NFTs that have been created
    // Because NFTs can be destroyed, it doesn't necessarily mean that this
    // reflects the total number of NFTs in existence, just the number that
    // have been minted to date.
    // Is also used as global moment IDs for minting
    pub var totalSupply: UInt64

    // -----------------------------------------------------------------------
    // TopShot contract-level Composite Type DEFINITIONS
    // -----------------------------------------------------------------------
    // These are just definitions for types that this contract
    // and other accounts can use. These definitions do not contain
    // actual stored values, but an instance (or object) of one of these types
    // can be created by this contract that contains stored values
    // -----------------------------------------------------------------------

    // Play is a Struct that holds metadata associated 
    // with a specific NBA play, like the legendary moment when 
    // Ray Allen hit the 3 to tie the Heat and Spurs in the 2013 finals game 6
    // or when Lance Stephenson blew in the ear of Lebron James
    //
    // Moment NFTs will all reference a single Play as the owner of
    // its metadata. The Plays are publicly accessible, so anyone can
    // read the metadata associated with a specific play ID
    //
    pub struct Play {

        // the unique ID that the Play has
        pub let playID: UInt32

        // Stores all the metadata about the Play as a string mapping
        // This is not the long term way we will do metadata. Just a temporary
        // construct while we figure out a better way to do metadata
        //
        pub let metadata: {String: String}

        init(metadata: {String: String}) {
            pre {
                metadata.length != 0: "Wrong amount of metadata!"
            }
            self.playID = TopShot.nextPlayID
            self.metadata = metadata

            // increment the ID so that it isn't used again
            TopShot.nextPlayID = TopShot.nextPlayID + UInt32(1)

            emit PlayCreated(id: self.playID)
        }
    }

    // A Set is a grouping of plays that have occured in the real world
    // that make up a related group of collectibles, like sets of baseball
    // or Magic cards.
    // 
    // SetData is a struct that is stored in a public field of the contract.
    // This is to allow anyone to be able to query the constant information
    // about a set but not have the ability to modify any data in the 
    // private set resource
    //
    pub struct SetData {

        // unique ID for the set
        pub let setID: UInt32

        // Name of the Set
        // ex. "Times when the Toronto Raptors choked in the playoffs"
        pub let name: String

        // Series that this set belongs to
        // Series is a concept that indicates a group of sets through time
        // Many sets can exist at a time, but only one series
        pub let series: UInt32

        init(name: String) {
            pre {
                name.length > 0: "Name cannot be empty"
            }
            self.setID = TopShot.nextSetID
            self.name = name
            self.series = TopShot.currentSeries

            // increment the setID so that it isn't used again
            TopShot.nextSetID = TopShot.nextSetID + UInt32(1)

            emit SetCreated(setID: self.setID, series: self.series)
        }
    }

    // Set is a resource type that contains the functions to add and remove
    // plays from a set and mint moments.
    //
    // It is stored in a private field in the contract so that
    // the admin resource can call its methods and that there can be
    // public getters for some of its fields
    //
    // Because of this, it acts as an admin resource to add and
    // remove plays from sets, and mint new moments.
    //
    // The admin can add Plays to a set so that the set can mint moments
    // that reference that playdata.
    // The moments that are minted by a set will be listed as belonging to
    // the set that minted it, as well as the Play it references
    // 
    // The admin can also retire plays from the set, meaning that the retired
    // play can no longer have moments minted from it.
    //
    // If the admin locks the Set, then no more plays can be added to it
    //
    // If retireAll() and lock() are called back to back, 
    // the Set is closed off forever
    pub resource Set {

        // unique ID for the set
        pub let setID: UInt32

        // Array of plays that are a part of this set
        // When a play is added to the set, its ID gets appended here
        // The ID does not get removed from this array when a play is retired
        pub var plays: [UInt32]

        // Indicates if a play in this set can be minted
        // A play is set to false when it is added to a set
        // to indicate that it is still active
        // When the play is retired, this is set to true and cannot be changed
        pub var retired: {UInt32: Bool}

        // Indicates if the set is currently locked
        // When a set is created, it is unlocked 
        // and plays are allowed to be added to it
        // When a set is locked, plays cannot be added
        // A set can never be changed from locked to unlocked
        // The decision to lock it is final
        // If a set is locked, plays cannot be added, but
        // moments can still be minted from plays
        // that already had been added to it.
        pub var locked: Bool

        // Indicates the number of moments 
        // that have been minted per play in this set
        // When a moment is minted, this value is stored in the moment to
        // show where in the play set it is so far. ex. 13 of 60
        pub var numberMintedPerPlay: {UInt32: UInt32}

        init(name: String) {
            self.setID = TopShot.nextSetID
            self.plays = []
            self.retired = {}
            self.locked = false
            self.numberMintedPerPlay = {}

            TopShot.setDatas[self.setID] = SetData(name: name)
        }

        // addPlay adds a play to the set
        //
        // Parameters: playID: The ID of the play that is being added
        //
        // Pre-Conditions:
        // The play needs to be an existing play
        // The set needs to be not locked
        // The play can't have already been added to the set
        //
        pub fun addPlay(playID: UInt32) {
            pre {
                TopShot.playDatas[playID] != nil: "Play doesn't exist"
                !self.locked: "Cannot add a play after the set has been locked"
                self.numberMintedPerPlay[playID] != nil: "The play has already beed added to the set"
            }

            // Add the play to the array of plays
            self.plays.append(playID)

            // Open the play up for minting
            self.retired[playID] = false

            // Initialize the moment count to zero
            self.numberMintedPerPlay[playID] = 0

            emit PlayAddedToSet(setID: self.setID, playID: playID)
        }

        // retirePlay retires a play from the set so that it can't mint new moments
        //
        // Parameters: playID: The ID of the play that is being retired
        //
        // Pre-Conditions:
        // The play needs to be an existing play that is currently open for minting
        // 
        pub fun retirePlay(playID: UInt32) {
            if !self.retired[playID]! {
                self.retired[playID] = true

                emit PlayRetiredFromSet(setID: self.setID, playID: playID, numMoments: self.numberMintedPerPlay[playID]!)
            }
        }

        // retireAll retires all the plays in the set
        // Afterwards, none of the retired plays will be able to mint new moments
        //
        pub fun retireAll() {
            var i = 0
            while i < self.plays.length {
                self.retirePlay(playID: self.plays[i])
                i = i + 1
            }
        }

        // lock() locks the set so that no more plays can be added to it
        //
        // Pre-Conditions:
        // The set cannot already have been locked
        pub fun lock() {
            if !self.locked {
                self.locked = true
                emit SetLocked(setID: self.setID)
            }
        }

        // mintMoment mints a new moment and returns the newly minted moment
        // 
        // Parameters: playID: The ID of the play that the moment references
        //
        // Pre-Conditions:
        // The play must exist in the set and be allowed to mint new moments
        //
        // Returns: The NFT that was minted
        // 
        pub fun mintMoment(playID: UInt32): @NFT {
            // Revert if this play cannot be minted
            if let retired = self.retired[playID] {
                if retired {
                    panic("This play has been retired. Minting is disallowed")
                }
             } else { panic("This play doesn't exist") }

            // get the number of moments that have been minted for this play
            // to use as this moment's serial number
            let numInPlay = self.numberMintedPerPlay[playID] ?? panic("This play doesn't exist")

            // mint the new moment
            let newMoment: @NFT <- create NFT(serialNumber: numInPlay,
                                              playID: playID,
                                              setID: self.setID)

            // Increment the count of moments minted for this play
            self.numberMintedPerPlay[playID] = numInPlay + UInt32(1)

            return <-newMoment
        }

        // batchMintMoment mints an arbitrary quantity of moments 
        // and returns them as a Collection
        //
        // Parameters: playID: the ID of the play that the moments are minted for
        //             quantity: The quantity of moments to be minted
        //
        // Returns: Collection object that contains all the moments that were minted
        //
        pub fun batchMintMoment(playID: UInt32, quantity: UInt64): @Collection {
            let newCollection <- create Collection()

            var i: UInt64 = 0
            while i < quantity {
                newCollection.deposit(token: <-self.mintMoment(playID: playID))
            }

            return <-newCollection
        }
    }

    pub struct MomentData {
        // global unique moment ID
        pub let momentID: UInt64

        // the ID of the Set that the Moment comes from
        pub let setID: UInt32

        // the ID of the Play that the moment references
        pub let playID: UInt32

        // the place in the play that this moment was minted
        // Otherwise know as the serial number
        pub let serialNumber: UInt32

        init(momentID: UInt64, setID: UInt32, playID: UInt32, serialNumber: UInt32) {
            self.momentID = momentID
            self.setID = setID
            self.playID = playID
            self.serialNumber = serialNumber
        }

    }

    // The resource that represents the Moment NFTs
    //
    pub resource NFT: NonFungibleToken.INFT {

        pub let id: UInt64
        
        pub let data: MomentData

        pub var metadata: {String:String}

        init(serialNumber: UInt32, playID: UInt32, setID: UInt32) {
            self.id = TopShot.totalSupply

            self.data = MomentData(momentID: self.id, setID: setID, playID: playID, serialNumber: serialNumber)

            self.metadata = {}

            emit MomentMinted(momentID: self.id, playID: playID, setID: self.data.setID, serialNumber: self.data.serialNumber)

            // Increment the global moment IDs
            TopShot.totalSupply = TopShot.totalSupply + UInt64(1)
        }
    }

    // Admin is a special authorization resource that 
    // allows the owner to perform important functions to modify the 
    // various aspects of the plays, sets, and moments
    //
    pub resource Admin {

        // createPlay creates a new Play struct 
        // and stores it in the plays dictionary in the TopShot smart contract
        //
        // Parameters: metadata: A dictionary mapping metadata titles to their data
        //                       example: {"Player Name": "Kevin Durant", "Height": "7 feet"}
        //                               (because we all know Kevin Durant is not 6'9")
        //
        // Returns: the ID of the new Play object
        pub fun createPlay(metadata: {String: String}): UInt32 {
            // Create the new Play
            var newPlay = Play(metadata: metadata)
            let newID = newPlay.playID

            // Store it in the contract storage
            TopShot.playDatas[TopShot.nextPlayID] = newPlay

            return newID
        }

        // createSet creates a new Set resource and returns it
        // so that the caller can store it in their account
        //
        // Parameters: name: The name of the set
        //             series: The series that the set belongs to
        //
        // Returns: The newly created set object
        //
        pub fun createSet(name: String) {
            // Create the new Set
            var newSet <- create Set(name: name)

            TopShot.sets[newSet.setID] <-! newSet
        }

        // getSetRef returns a reference to a set in the TopShot
        // contract so that the admin can call methods on it
        //
        // Parameters: setID: The ID of the set that you want to
        // get a reference to
        //
        // Returns: A reference to the set with all of the fields
        // and methods exposed
        //
        pub fun getSetRef(setID: UInt32): &Set {
            return &TopShot.sets[setID] as &Set
        }

        // startNewSeries ends the current series by incrementing
        // the series number, meaning that moments will be using the 
        // new series number from now on
        //
        // Returns: The new series number
        //
        pub fun startNewSeries(): UInt32 {
            // end the current series and start a new one
            // by incrementing the TopShot series number
            TopShot.currentSeries = TopShot.currentSeries + UInt32(1)

            emit NewSeriesStarted(newCurrentSeries: TopShot.currentSeries)

            return TopShot.currentSeries
        }

        // createNewAdmin creates a new Admin Resource
        //
        pub fun createNewAdmin(): @Admin {
            return <-create Admin()
        }
    }

    // This is the interface that users can cast their moment Collection as
    // to allow others to deposit moments into their collection
    pub resource interface MomentCollectionPublic {
        pub fun deposit(token: @NFT)
        pub fun batchDeposit(tokens: @Collection)
        pub fun getIDs(): [UInt64]
        pub fun getNumberInPlaySet(id: UInt64): UInt32?
        pub fun getPlayID(id: UInt64): UInt32?
        pub fun getSetID(id: UInt64): UInt32?
        pub fun getSetName(id: UInt64): String?
        pub fun getSeries(id:UInt64): UInt32?
        pub fun getMetaData(id: UInt64): {String: String}?
    }

    // Collection is a resource that every user who owns NFTs 
    // will store in their account to manage their NFTS
    //
    pub resource Collection: MomentCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.Metadata { 
        // Dictionary of Moment conforming tokens
        // NFT is a resource type with a UInt64 ID field
        pub var ownedNFTs: @{UInt64: NFT}

        init() {
            self.ownedNFTs <- {}
        }

        // withdraw removes an Moment from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing Moment")

            emit Withdraw(id: token.id, from: self.owner?.address)
            
            return <-token
        }

        // batchWithdraw withdraws multiple tokens and returns them as a Collection
        pub fun batchWithdraw(ids: [UInt64]): @Collection {
            var i = 0
            var batchCollection: @Collection <- create Collection()

            while i < ids.length {
                batchCollection.deposit(token: <-self.withdraw(withdrawID: ids[i]))

                i = i + 1
            }
            return <-batchCollection
        }

        // deposit takes a Moment and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NFT) {
            let id = token.id
            // add the new token to the dictionary
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // batchDeposit takes a Collection object as an argument
        // and deposits each contained NFT into this collection
        pub fun batchDeposit(tokens: @Collection) {
            var i = 0
            let keys = tokens.getIDs()

            while i < keys.length {
                self.deposit(token: <-tokens.withdraw(withdrawID: keys[i]))

                i = i + 1
            }
            destroy tokens
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // The following functions get a certain piece of metadata
        // associated with a single Moment in the Collection
        //
        // Parameter: id: The ID of the Moment to get the data from
        //
        // Returns: nil if the NFT doesn't exist, 
        //          otherwise it returns the correct data

        pub fun getPlayID(id: UInt64): UInt32? {
            return self.ownedNFTs[id]?.data?.playID
        }

        pub fun getNumberInPlaySet(id: UInt64): UInt32? {
            return self.ownedNFTs[id]?.data?.serialNumber
        }

        pub fun getSetID(id: UInt64): UInt32? {
            return self.ownedNFTs[id]?.data?.setID
        }

        pub fun getSetName(id: UInt64): String? {
            if let setID = self.ownedNFTs[id]?.data?.setID {
                return TopShot.setDatas[setID]?.name
            } else {
                return nil
            }
        }

        pub fun getSeries(id:UInt64): UInt32? {
            if let setID = self.ownedNFTs[id]?.data?.setID {
                return TopShot.setDatas[setID]?.series
            } else {
                return nil
            }
        }

        pub fun getMetaData(id: UInt64): {String: String}? {
            if let PlayID = self.getPlayID(id: id) {
                return TopShot.playDatas[PlayID]?.metadata
            } else {
                return nil
            }
        }

        // If a transaction destroys the Collection object,
        // All the NFTs contained within are also destroyed
        // Kind of like when Damien Lillard destroys the hopes and
        // dreams of the entire city of Houston
        //
        destroy() {
            destroy self.ownedNFTs
        }
    }

    // -----------------------------------------------------------------------
    // TopShot contract-level function definitions
    // -----------------------------------------------------------------------

    // createEmptyCollection creates a new, empty Collection object so that
    // a user can store it in their account storage.
    // Once they have a Collection in their storage, they are able to receive
    // Moments in transactions
    //
    pub fun createEmptyCollection(): @Collection {
        return <-create Collection()
    }

    // getPlayMetaData returns all the metadata associated with a specific play
    // 
    // Parameters: playID: The id of the play that is being searched
    //
    // Returns: The metadata as a String to String mapping optional
    pub fun getPlayMetaData(playID: UInt32): {String: String}? {
        return self.playDatas[playID]?.metadata
    }

    // getPlayMetaDataByField returns the metadata associated with a 
    //                        specific field of the metadata
    //                        Ex: field: "Team" will return something
    //                        like "Memphis Grizzlies"
    // 
    // Parameters: playID: The id of the play that is being searched
    //             field: The field to search for
    //
    // Returns: The metadata field as a String Optional
    pub fun getPlayMetaDataByField(playID: UInt32, field: String): String? {
        if let metadata = TopShot.playDatas[playID]?.metadata {
            return metadata[field]
        } else {
            return nil
        }
    }

    // -----------------------------------------------------------------------
    // TopShot initialization function
    // -----------------------------------------------------------------------
    //
    init() {
        // initialize the fields
        self.currentSeries = 0
        self.playDatas = {}
        self.setDatas = {}
        self.sets <- {}
        self.nextPlayID = 0
        self.nextSetID = 0
        self.totalSupply = 0

        // Create a new collection
        let oldCollection <- self.account.storage[Collection] <- create Collection()
        destroy oldCollection

        // Create a safe, public reference to the Collection 
        // and store it in public reference storage
        self.account.published[&Collection{MomentCollectionPublic}] = &self.account.storage[Collection] as &Collection{MomentCollectionPublic}

        // Create a new Admin resource and store it
        let oldAdmin <- self.account.storage[Admin] <- create Admin()
        destroy oldAdmin

        emit ContractInitialized()
    }
}
 