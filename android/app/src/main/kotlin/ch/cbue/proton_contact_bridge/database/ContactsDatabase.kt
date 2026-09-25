package ch.cbue.proton_contact_bridge.database

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.core.database.getStringOrNull
import com.github.f4b6a3.ulid.Ulid
import java.io.File

class ContactsDatabase(context: Context) : AutoCloseable {
    private val db = SQLiteDatabase.openDatabase(
        dbFile(context),
        SQLiteDatabase.OpenParams.Builder()
            .setJournalMode("WAL")
            .addOpenFlags(SQLiteDatabase.OPEN_READWRITE)
            .build()
    )

    fun getAllContacts(): List<Contact> {
        val contacts = mutableListOf<Contact>()

        db.rawQuery(
            """
            select id, decrypted_v_card
            from contacts
        """.trimIndent(), emptyArray()
        ).use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow("id")
            val cardCol = cursor.getColumnIndexOrThrow("decrypted_v_card")

            while (cursor.moveToNext()) {
                contacts += Contact(
                    id = cursor.getString(idCol),
                    vcardText = cursor.getString(cardCol),
                )
            }
        }

        return contacts
    }

    fun getModifiedContacts(afterEvent: Ulid): Triple<List<Contact>, List<String>, String?> {
        val upsertContacts = mutableMapOf<String, Contact>()
        val deleteContacts = mutableListOf<String>()
        var lastId: String? = null

        db.rawQuery(
            """
            select ce.id, ce.`action`, ce.contact_id, c.decrypted_v_card
            from contact_events ce
            left join contacts c on ce.contact_id = c.id
            where ce.id > ?
            order by ce.id
        """.trimIndent(), arrayOf(afterEvent.toString())
        ).use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow("ce.id")
            val aCol = cursor.getColumnIndexOrThrow("ce.action")
            val cidCol = cursor.getColumnIndexOrThrow("ce.contact_id")
            val cardCol = cursor.getColumnIndexOrThrow("c.decrypted_v_card")

            while (cursor.moveToNext()) {
                lastId = cursor.getString(idCol)
                val action = cursor.getInt(aCol)
                when (action) {
                    1 -> {
                        // upsert
                        val i = cursor.getStringOrNull(cidCol)
                        val v = cursor.getStringOrNull(cardCol)
                        if(i == null || v == null){
                            // contact may was deleted later
                            continue
                        }

                        val c = Contact(
                            id = cursor.getString(cidCol),
                            vcardText = cursor.getString(cardCol),
                        )
                        upsertContacts[c.id] = c
                    }

                    2 -> {
                        // delete
                        val i = cursor.getString(cidCol)
                        deleteContacts += i
                        upsertContacts.remove(i)
                    }

                    else -> continue
                }
            }
        }

        return Triple(
            upsertContacts.values.toList(),
            deleteContacts,
            lastId,
        )
    }

    fun removeEvents(beforeEvent: Ulid) {
        db.delete(
            "contact_events",
            "id <= ?",
            arrayOf(beforeEvent.toString())
        )
    }

    override fun close() {
        db.close()
    }

    companion object {
        fun dbFile(context: Context): File {
            val noBackupDir = context.noBackupFilesDir
            val dbFile = File(noBackupDir, "databases/proton_contacts.db")
            dbFile.parentFile?.mkdirs()
            return dbFile
        }

        fun path(context: Context): String {
            val file = dbFile(context)
            return file.absolutePath
        }
    }
}
