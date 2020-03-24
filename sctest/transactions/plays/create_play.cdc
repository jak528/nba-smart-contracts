import TopShot from 0x03

transaction {

    let adminRef: &TopShot.Admin

    prepare(acct: AuthAccount) {
        self.adminRef = &acct.storage[TopShot.Admin] as &TopShot.Admin
    }

    execute {
        
        let id1 = self.adminRef.createPlay(metadata: {"Name": "Lebron"})

        let id2 = self.adminRef.createPlay(metadata: {"Name": "Oladipo"})

        log("PlayData 1 and 2 Succcesfully created!")
    }
}
 