package ch.cbue.proton_contact_bridge.database

import ezvcard.Ezvcard
import ezvcard.VCard

data class Contact(
    val id: String,
    val vcardText: String,
) {
    val vcard: VCard
        get() = Ezvcard.parse(vcardText).first()
}
