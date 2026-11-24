# Question to Apple: sharing night results within a group

Send through **developer.apple.com/contact** → App Review → "Ask a question about the App Review Guidelines" (or as a reply to Apple's email about entitlement request **7B25Q38FCU**). Sender: the Account Holder.

---

**Subject:** Family Controls: can a user choose to share coarse night results with their own group?

Hello,

We requested the Family Controls distribution entitlement (request ID 7B25Q38FCU, team 8XRKL83C4V) for our app Moonlight (bundle IDs nl.moonlight.app and nl.moonlight.app.monitor). Before we go further, we'd like to confirm that our design fits the entitlement terms.

**What the app does.** Moonlight helps adults keep their own phone out of bed. Each person sets a personal "phone down by" time (for example 21:00). The app uses FamilyControls with `.individual` authorization on the person's own device, and DeviceActivity events at 2, 5, 15 and 60 minutes of use between that time and 07:00. It never manages anyone else's device and never sees app names or content.

**The social part.** People take part in small groups of friends (for example 4 students in a two-week sleep challenge, after a lecture on sleep). In the morning, each member sees how the group did. For each person and night, only one coarse value is shared: "phone-free" (under 2 minutes) or "at least 2 / 5 / 15 / 60 minutes", plus the time 2 minutes were reached. Members can react with an emoji. Nothing else from Screen Time leaves the device.

- Each person installs the app, authorizes Screen Time for themselves, and joins a group themselves with an invite code. The onboarding says clearly that the group will see these results.
- Anyone can leave the group at any time, which deletes their results from our server.
- No advertising, no analytics, no data brokers. The data is used only to show the group board.

**Our question.** The terms say usage data may not be shared "beyond … the individual and their device". Is it acceptable for an individual to opt in to sharing these coarse threshold results with a small group they chose to join? If not, would it be acceptable if the person confirms each morning what to share (for example a "share my night" button, with nothing sent automatically)?

We'd rather adapt the design now than after submission. Thank you.

Johannes Wolf
