# WorkSamples
This repository contains a curated selection of some of my past work on the Conquer Cadence application, of which I was the co-architect (along with one other SF developer) and chief designer.

In order to protect Conquer's proprietary technology, I have included only a cross section of work I have personally done and have cleared with Conquer for sharing on my GitHub.
Each directory will demonstrate a particular core competency, specifically:

* Bulk Cadence Enrollment: demonstrates the "Start" service which is used to enroll prospects into a Cadence (sales path), as well as a bulk upload tool implementing Batchable Apex, where managers can enroll over a million records into an Enterprise production org without exceeding governor limits.

* Conversation View: A flagship component of the Cadence app, Conversation View can be embedded onto any record page. It will display a timeline view of all calls, emails, text messages, and other custom step types (including 3rd party integrations) in a hub interface. In this interface they are also able to send outgoing emails, respond to incoming emails, and place calls, without leaving Conversation View.

* ScratchOrgSeedingScript: Contains Apex classes that I wrote for seeding new scratch edition Salesforce orgs with the data necessary to begin developing against the latest version of Master branch right away. For further ease of use, I also wrote a bash file which authenticates against Conquer's back end, spins up a scratch org, pushes the code base to the org, and seeds the org with the afore described data.

* TestFactory: Contains Apex classes I was tasked with writing in order to facilitate end-to-end unit testing without the need for developers to create and update their own test records, which, due to the complexity of the Cadence application, would require dozens of lines of boilerplate code.
