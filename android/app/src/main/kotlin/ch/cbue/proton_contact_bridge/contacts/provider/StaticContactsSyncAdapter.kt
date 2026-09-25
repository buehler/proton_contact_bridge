package ch.cbue.proton_contact_bridge.contacts.provider

import android.accounts.Account
import android.content.AbstractThreadedSyncAdapter
import android.content.ContentProviderClient
import android.content.ContentProviderOperation
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.SyncResult
import android.os.Bundle
import android.provider.ContactsContract
import android.provider.ContactsContract.CommonDataKinds.Email as EmailKind
import android.provider.ContactsContract.CommonDataKinds.Event as EventKind
import android.provider.ContactsContract.CommonDataKinds.GroupMembership as GroupMembershipKind
import android.provider.ContactsContract.CommonDataKinds.Nickname as NicknameKind
import android.provider.ContactsContract.CommonDataKinds.Note as NoteKind
import android.provider.ContactsContract.CommonDataKinds.Organization as OrganizationKind
import android.provider.ContactsContract.CommonDataKinds.Phone as PhoneKind
import android.provider.ContactsContract.CommonDataKinds.Photo as PhotoKind
import android.provider.ContactsContract.CommonDataKinds.StructuredName as NameKind
import android.provider.ContactsContract.CommonDataKinds.StructuredPostal as PostalKind
import android.provider.ContactsContract.CommonDataKinds.Website as WebsiteKind
import android.util.Log
import ch.cbue.proton_contact_bridge.R
import ch.cbue.proton_contact_bridge.database.Contact
import ch.cbue.proton_contact_bridge.database.ContactsDatabase
import com.github.f4b6a3.ulid.Ulid
import ezvcard.property.DateOrTimeProperty
import java.io.IOException
import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlin.time.Clock
import kotlin.time.Duration

class StaticContactsSyncAdapter(
    context: Context,
    autoInitialize: Boolean,
) : AbstractThreadedSyncAdapter(context, autoInitialize) {
    private val cursorState = ContactsSyncCursorState(context)

    override fun onPerformSync(
        account: Account?,
        extras: Bundle?,
        authority: String?,
        provider: ContentProviderClient?,
        syncResult: SyncResult?
    ) {
        Log.d(TAG, "Perform Sync")

        if (account == null) {
            Log.w(TAG, "account is null, abort.")
            return
        }
        if (provider == null) {
            Log.w(TAG, "provider is null, abort.")
            return
        }
        if (syncResult == null) {
            Log.w(TAG, "sync result is null, abort.")
            return
        }

        try {
            val todos = calcTodos()
            if (todos.empty) {
                Log.i(TAG, "no sync todos. abort.")
                return
            }

            Log.i(
                TAG,
                "execute sync with id: ${todos.latestEventId}, ${todos.upsert.size} upsert, and ${todos.delete.size} deletes"
            )
            val rawUri = ContactsContract.RawContacts.CONTENT_URI.buildUpon()
                .appendQueryParameter(ContactsContract.CALLER_IS_SYNCADAPTER, "true")
                .build()
            val dataUri = ContactsContract.Data.CONTENT_URI.buildUpon()
                .appendQueryParameter(ContactsContract.CALLER_IS_SYNCADAPTER, "true")
                .build()
            val groupUri = ContactsContract.Groups.CONTENT_URI.buildUpon()
                .appendQueryParameter(ContactsContract.CALLER_IS_SYNCADAPTER, "true")
                .build()
            val settingsUri = ContactsContract.Settings.CONTENT_URI.buildUpon()
                .appendQueryParameter(ContactsContract.CALLER_IS_SYNCADAPTER, "true")
                .build()
            val accountSelection = "${ContactsContract.RawContacts.ACCOUNT_NAME}=? AND " +
                    "${ContactsContract.RawContacts.ACCOUNT_TYPE}=?"
            val accountArgs = arrayOf(account.name, account.type)

            fun findRawContact(sourceId: String): Triple<Long, Int, Int>? {
                val cursor = provider.query(
                    rawUri,
                    arrayOf(
                        ContactsContract.RawContacts._ID,
                        ContactsContract.RawContacts.STARRED,
                        ContactsContract.RawContacts.DELETED,
                    ),
                    "$accountSelection AND ${ContactsContract.RawContacts.SOURCE_ID}=?",
                    arrayOf(account.name, account.type, sourceId),
                    null,
                ) ?: throw IOException("Raw contact query returned no cursor")
                return cursor.use {
                    if (it.moveToFirst()) Triple(
                        it.getLong(0),
                        it.getInt(1),
                        it.getInt(2)
                    ) else null
                }
            }

            val managedMimes = setOf(
                NameKind.CONTENT_ITEM_TYPE,
                NicknameKind.CONTENT_ITEM_TYPE,
                PhoneKind.CONTENT_ITEM_TYPE,
                EmailKind.CONTENT_ITEM_TYPE,
                PostalKind.CONTENT_ITEM_TYPE,
                OrganizationKind.CONTENT_ITEM_TYPE,
                EventKind.CONTENT_ITEM_TYPE,
                NoteKind.CONTENT_ITEM_TYPE,
                WebsiteKind.CONTENT_ITEM_TYPE,
                PhotoKind.CONTENT_ITEM_TYPE,
            )
            val dataColumns = arrayOf(
                ContactsContract.Data.DATA1, ContactsContract.Data.DATA2,
                ContactsContract.Data.DATA3, ContactsContract.Data.DATA4,
                ContactsContract.Data.DATA5, ContactsContract.Data.DATA6,
                ContactsContract.Data.DATA7, ContactsContract.Data.DATA8,
                ContactsContract.Data.DATA9, ContactsContract.Data.DATA10,
                ContactsContract.Data.DATA15,
            )

            fun row(mime: String, vararg fields: Pair<String, Any?>): ContentValues =
                ContentValues().apply {
                    put(ContactsContract.Data.MIMETYPE, mime)
                    for ((key, value) in fields) {
                        when (value) {
                            null -> putNull(key)
                            is String -> put(key, value)
                            is Int -> put(key, value)
                            is ByteArray -> put(key, value)
                            else -> error("Unsupported contact data value: $key")
                        }
                    }
                }

            fun sameData(current: ContentValues, desired: ContentValues): Boolean =
                desired.valueSet().all { (key, value) ->
                    if (value is ByteArray) {
                        value.contentEquals(current.getAsByteArray(key))
                    } else {
                        desired.getAsString(key) == current.getAsString(key)
                    }
                }

            fun dateValue(value: DateOrTimeProperty): String? =
                value.date?.toString() ?: value.partialDate?.toString() ?: value.text

            fun typeAndLabel(
                values: List<String>,
                known: Map<String, Int>,
                other: Int,
                custom: Int,
            ): Pair<Int, String?> {
                val labels = values.map { it.trim() }.filter { it.isNotEmpty() }
                if (labels.isEmpty()) return other to null
                val type = labels.singleOrNull()?.lowercase()?.let(known::get)
                return if (type != null) type to null else custom to labels.joinToString(", ")
            }

            val phoneTypes = mapOf(
                "mobile" to PhoneKind.TYPE_MOBILE,
                "cell" to PhoneKind.TYPE_MOBILE,
                "home" to PhoneKind.TYPE_HOME,
                "work" to PhoneKind.TYPE_WORK,
                "main" to PhoneKind.TYPE_MAIN,
                "other" to PhoneKind.TYPE_OTHER,
            )
            val emailTypes = mapOf(
                "home" to EmailKind.TYPE_HOME,
                "work" to EmailKind.TYPE_WORK,
                "other" to EmailKind.TYPE_OTHER,
            )
            val addressTypes = mapOf(
                "home" to PostalKind.TYPE_HOME,
                "work" to PostalKind.TYPE_WORK,
                "other" to PostalKind.TYPE_OTHER,
            )

            for (contact in todos.upsert) {
                val card = try {
                    contact.vcard
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to parse vCard for ${contact.id}", e)
                    syncResult.stats.numParseExceptions++
                    continue
                }
                val desired = mutableListOf<ContentValues>()
                val structuredName = card.structuredName
                val formattedName = card.formattedName?.value
                if (structuredName != null || !formattedName.isNullOrBlank()) {
                    desired += row(
                        NameKind.CONTENT_ITEM_TYPE,
                        NameKind.DISPLAY_NAME to formattedName,
                        NameKind.GIVEN_NAME to structuredName?.given,
                        NameKind.FAMILY_NAME to structuredName?.family,
                        NameKind.MIDDLE_NAME to structuredName?.additionalNames?.joinToString(" "),
                        NameKind.PREFIX to structuredName?.prefixes?.joinToString(" "),
                        NameKind.SUFFIX to structuredName?.suffixes?.joinToString(" "),
                    )
                }
                for (value in card.nicknames.flatMap { it.values }) {
                    desired += row(
                        NicknameKind.CONTENT_ITEM_TYPE,
                        NicknameKind.NAME to value,
                        NicknameKind.TYPE to NicknameKind.TYPE_DEFAULT,
                        NicknameKind.LABEL to null,
                    )
                }
                for (value in card.telephoneNumbers) {
                    val number = value.text ?: value.uri?.number ?: continue
                    val (type, label) = typeAndLabel(
                        value.parameters.types, phoneTypes,
                        PhoneKind.TYPE_OTHER, PhoneKind.TYPE_CUSTOM,
                    )
                    desired += row(
                        PhoneKind.CONTENT_ITEM_TYPE,
                        PhoneKind.NUMBER to number,
                        PhoneKind.TYPE to type,
                        PhoneKind.LABEL to label,
                    )
                }
                for (value in card.emails) {
                    val (type, label) = typeAndLabel(
                        value.parameters.types, emailTypes,
                        EmailKind.TYPE_OTHER, EmailKind.TYPE_CUSTOM,
                    )
                    desired += row(
                        EmailKind.CONTENT_ITEM_TYPE,
                        EmailKind.ADDRESS to value.value,
                        EmailKind.TYPE to type,
                        EmailKind.LABEL to label,
                    )
                }
                for (value in card.addresses) {
                    val (type, label) = typeAndLabel(
                        value.parameters.types, addressTypes,
                        PostalKind.TYPE_OTHER, PostalKind.TYPE_CUSTOM,
                    )
                    desired += row(
                        PostalKind.CONTENT_ITEM_TYPE,
                        PostalKind.FORMATTED_ADDRESS to listOfNotNull(
                            value.streetAddressFull, value.locality, value.region,
                            value.postalCode, value.country,
                        ).joinToString(", ").ifEmpty { null },
                        PostalKind.STREET to value.streetAddressFull,
                        PostalKind.POBOX to value.poBox,
                        PostalKind.NEIGHBORHOOD to value.extendedAddressFull,
                        PostalKind.CITY to value.locality,
                        PostalKind.REGION to value.region,
                        PostalKind.POSTCODE to value.postalCode,
                        PostalKind.COUNTRY to value.country,
                        PostalKind.TYPE to type,
                        PostalKind.LABEL to label,
                    )
                }
                val jobCount = maxOf(card.organizations.size, card.titles.size, card.roles.size)
                for (index in 0 until jobCount) {
                    val company = card.organizations.getOrNull(index)?.values.orEmpty()
                    desired += row(
                        OrganizationKind.CONTENT_ITEM_TYPE,
                        OrganizationKind.COMPANY to company.firstOrNull(),
                        OrganizationKind.DEPARTMENT to company.drop(1).joinToString(" / ")
                            .ifEmpty { null },
                        OrganizationKind.TITLE to card.titles.getOrNull(index)?.value,
                        OrganizationKind.JOB_DESCRIPTION to card.roles.getOrNull(index)?.value,
                        OrganizationKind.TYPE to OrganizationKind.TYPE_WORK,
                        OrganizationKind.LABEL to null,
                    )
                }
                for (value in card.birthdays) {
                    val date = dateValue(value) ?: continue
                    desired += row(
                        EventKind.CONTENT_ITEM_TYPE,
                        EventKind.START_DATE to date,
                        EventKind.TYPE to EventKind.TYPE_BIRTHDAY,
                        EventKind.LABEL to null,
                    )
                }
                for (value in card.anniversaries) {
                    val date = dateValue(value) ?: continue
                    desired += row(
                        EventKind.CONTENT_ITEM_TYPE,
                        EventKind.START_DATE to date,
                        EventKind.TYPE to EventKind.TYPE_ANNIVERSARY,
                        EventKind.LABEL to null,
                    )
                }
                for (value in card.notes) {
                    desired += row(NoteKind.CONTENT_ITEM_TYPE, NoteKind.NOTE to value.value)
                }
                for (value in card.urls) {
                    desired += row(
                        WebsiteKind.CONTENT_ITEM_TYPE,
                        WebsiteKind.URL to value.value,
                        WebsiteKind.TYPE to WebsiteKind.TYPE_OTHER,
                        WebsiteKind.LABEL to null,
                    )
                }
                for (value in card.photos) {
                    val bytes = value.data ?: continue
                    desired += row(PhotoKind.CONTENT_ITEM_TYPE, PhotoKind.PHOTO to bytes)
                }

                val favorite = card.extendedProperties.any {
                    it.propertyName.equals("X-PCB-FAVORITE", ignoreCase = true) &&
                            it.value.equals("true", ignoreCase = true)
                }
                val existing = findRawContact(contact.id)
                val operations = ArrayList<ContentProviderOperation>()
                if (existing == null) {
                    operations += ContentProviderOperation.newInsert(rawUri)
                        .withValue(ContactsContract.RawContacts.ACCOUNT_NAME, account.name)
                        .withValue(ContactsContract.RawContacts.ACCOUNT_TYPE, account.type)
                        .withValue(ContactsContract.RawContacts.SOURCE_ID, contact.id)
                        .withValue(ContactsContract.RawContacts.STARRED, if (favorite) 1 else 0)
                        .build()
                    for (value in desired) {
                        operations += ContentProviderOperation.newInsert(dataUri)
                            .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                            .withValues(value)
                            .build()
                    }
                } else {
                    val rawId = existing.first
                    if (existing.second != (if (favorite) 1 else 0) || existing.third != 0) {
                        operations += ContentProviderOperation.newUpdate(
                            ContentUris.withAppendedId(
                                rawUri,
                                rawId
                            )
                        )
                            .withValue(ContactsContract.RawContacts.STARRED, if (favorite) 1 else 0)
                            .withValue(ContactsContract.RawContacts.DELETED, 0)
                            .build()
                    }

                    val existingRows =
                        mutableMapOf<String, MutableList<Pair<Long, ContentValues>>>()
                    val cursor = provider.query(
                        dataUri,
                        arrayOf(
                            ContactsContract.Data._ID,
                            ContactsContract.Data.MIMETYPE,
                            *dataColumns
                        ),
                        "${ContactsContract.Data.RAW_CONTACT_ID}=?",
                        arrayOf(rawId.toString()),
                        "${ContactsContract.Data._ID} ASC",
                    ) ?: throw IOException("Contact data query returned no cursor")
                    cursor.use {
                        while (it.moveToNext()) {
                            val mime = it.getString(1)
                            if (mime !in managedMimes) continue
                            val current =
                                ContentValues().apply { put(ContactsContract.Data.MIMETYPE, mime) }
                            for (column in dataColumns) {
                                val columnIndex = it.getColumnIndexOrThrow(column)
                                if (it.isNull(columnIndex)) current.putNull(column)
                                else if (column == ContactsContract.Data.DATA15) current.put(
                                    column,
                                    it.getBlob(columnIndex)
                                )
                                else current.put(column, it.getString(columnIndex))
                            }
                            existingRows.getOrPut(mime) { mutableListOf() } += it.getLong(0) to current
                        }
                    }

                    for (value in desired) {
                        val mime = value.getAsString(ContactsContract.Data.MIMETYPE)
                        val rows = existingRows.getOrPut(mime) { mutableListOf() }
                        val exactIndex = rows.indexOfFirst { sameData(it.second, value) }
                        val current = when {
                            exactIndex >= 0 -> rows.removeAt(exactIndex)
                            rows.isNotEmpty() -> rows.removeAt(0)
                            else -> null
                        }
                        if (current == null) {
                            operations += ContentProviderOperation.newInsert(dataUri)
                                .withValue(ContactsContract.Data.RAW_CONTACT_ID, rawId)
                                .withValues(value)
                                .build()
                        } else if (!sameData(current.second, value)) {
                            val update =
                                ContentValues(value).apply { remove(ContactsContract.Data.MIMETYPE) }
                            operations += ContentProviderOperation.newUpdate(
                                ContentUris.withAppendedId(dataUri, current.first)
                            ).withValues(update).build()
                        }
                    }
                    for (rows in existingRows.values) {
                        for ((dataId, _) in rows) {
                            operations += ContentProviderOperation.newDelete(
                                ContentUris.withAppendedId(dataUri, dataId)
                            ).build()
                        }
                    }
                }
                if (operations.isEmpty()) {
                    syncResult.stats.numSkippedEntries++
                } else {
                    val results = provider.applyBatch(operations)
                    if (results.any { it.uri != null || (it.count ?: 0) > 0 }) {
                        if (existing == null) syncResult.stats.numInserts++
                        else syncResult.stats.numUpdates++
                    } else {
                        syncResult.stats.numSkippedEntries++
                    }
                }
                syncResult.stats.numEntries++
            }

            if (todos.upsert.isNotEmpty()) {
                val settings = ContentValues().apply {
                    put(ContactsContract.Settings.UNGROUPED_VISIBLE, 1)
                }
                if (provider.update(settingsUri, settings, accountSelection, accountArgs) == 0) {
                    settings.put(ContactsContract.Settings.ACCOUNT_NAME, account.name)
                    settings.put(ContactsContract.Settings.ACCOUNT_TYPE, account.type)
                    provider.insert(settingsUri, settings)
                }
            }

            for (id in todos.delete) {
                val rawId = findRawContact(id)?.first
                if (rawId == null) {
                    syncResult.stats.numSkippedEntries++
                    syncResult.stats.numEntries++
                    continue
                }
                val results = provider.applyBatch(
                    arrayListOf(
                        ContentProviderOperation.newDelete(
                            ContentUris.withAppendedId(
                                rawUri,
                                rawId
                            )
                        ).build()
                    )
                )
                if ((results.single().count ?: 0) > 0) syncResult.stats.numDeletes++
                else syncResult.stats.numSkippedEntries++
                syncResult.stats.numEntries++
            }

            val groupTitle = context.getString(R.string.app_name)
            val groupCursor = provider.query(
                groupUri,
                arrayOf(
                    ContactsContract.Groups._ID,
                    ContactsContract.Groups.TITLE,
                    ContactsContract.Groups.DELETED,
                ),
                "${ContactsContract.Groups.ACCOUNT_NAME}=? AND " +
                        "${ContactsContract.Groups.ACCOUNT_TYPE}=? AND " +
                        "${ContactsContract.Groups.SOURCE_ID}=?",
                arrayOf(account.name, account.type, GROUP_SOURCE_ID),
                null,
            ) ?: throw IOException("KinCrypt group query returned no cursor")
            val existingGroup = groupCursor.use {
                if (it.moveToFirst()) Triple(it.getLong(0), it.getString(1), it.getInt(2))
                else null
            }
            val groupId = if (existingGroup == null) {
                val values = ContentValues().apply {
                    put(ContactsContract.Groups.ACCOUNT_NAME, account.name)
                    put(ContactsContract.Groups.ACCOUNT_TYPE, account.type)
                    put(ContactsContract.Groups.SOURCE_ID, GROUP_SOURCE_ID)
                    put(ContactsContract.Groups.TITLE, groupTitle)
                }
                val inserted = provider.insert(groupUri, values)
                    ?: throw IOException("Unable to create KinCrypt group")
                ContentUris.parseId(inserted)
            } else {
                if (existingGroup.second != groupTitle || existingGroup.third != 0) {
                    val values = ContentValues().apply {
                        put(ContactsContract.Groups.TITLE, groupTitle)
                        put(ContactsContract.Groups.DELETED, 0)
                    }
                    if (provider.update(
                            ContentUris.withAppendedId(groupUri, existingGroup.first),
                            values,
                            null,
                            null,
                        ) != 1
                    ) throw IOException("Unable to update KinCrypt group")
                }
                existingGroup.first
            }

            val rawIds = mutableSetOf<Long>()
            val rawCursor = provider.query(
                rawUri,
                arrayOf(ContactsContract.RawContacts._ID),
                "$accountSelection AND ${ContactsContract.RawContacts.DELETED}=0",
                accountArgs,
                null,
            ) ?: throw IOException("KinCrypt contact query returned no cursor")
            rawCursor.use {
                while (it.moveToNext()) rawIds += it.getLong(0)
            }

            val memberIds = mutableSetOf<Long>()
            val membershipCursor = provider.query(
                dataUri,
                arrayOf(ContactsContract.Data.RAW_CONTACT_ID),
                "${ContactsContract.Data.MIMETYPE}=? AND ${GroupMembershipKind.GROUP_ROW_ID}=?",
                arrayOf(GroupMembershipKind.CONTENT_ITEM_TYPE, groupId.toString()),
                null,
            ) ?: throw IOException("KinCrypt group membership query returned no cursor")
            membershipCursor.use {
                while (it.moveToNext()) memberIds += it.getLong(0)
            }

            for (ids in (rawIds - memberIds).chunked(100)) {
                val operations = ArrayList<ContentProviderOperation>(ids.size)
                for (rawId in ids) {
                    operations += ContentProviderOperation.newInsert(dataUri)
                        .withValue(ContactsContract.Data.RAW_CONTACT_ID, rawId)
                        .withValue(
                            ContactsContract.Data.MIMETYPE,
                            GroupMembershipKind.CONTENT_ITEM_TYPE
                        )
                        .withValue(GroupMembershipKind.GROUP_ROW_ID, groupId)
                        .build()
                }
                val results = provider.applyBatch(operations)
                if (results.size != operations.size || results.any { it.uri == null }) {
                    throw IOException("Unable to add KinCrypt group memberships")
                }
            }

            if (todos.initial) {
                Log.d(TAG, "store new ULID to show init sync done")
                cursorState.set(Ulid.MIN.increment())
            } else if (todos.latestEventId != null) {
                Log.d(TAG, "cleanup processed events")
                ContactsDatabase(context).use { db ->
                    db.removeEvents(todos.latestEventId)
                }
                Log.d(TAG, "set latest processed event id to ${todos.latestEventId}")
                cursorState.set(todos.latestEventId)
            } else {
                Log.d(TAG, "no latest event id")
            }

            Log.i(TAG, "sync successfully performed.")
        } catch (e: Exception) {
            Log.e(TAG, "Contact sync failed", e)
            syncResult.stats.numIoExceptions++
        }
    }

    private fun calcTodos(): ContactTodos {
        ContactsDatabase(context).use { db ->
            if (cursorState.isInit) {
                Log.i(TAG, "cursor state initial, perform full sync.")
                val c = db.getAllContacts()
                return ContactTodos(c, emptyList(), true, null)
            }

            val (upsert, delete, e) = db.getModifiedContacts(cursorState.get())

            return ContactTodos(upsert, delete, false, if (e != null) Ulid.from(e) else null)
        }
    }

    companion object {
        private const val TAG = "ContactSyncAdapter"
        private const val GROUP_SOURCE_ID = "kincrypt_all"
    }
}

private data class ContactTodos(
    val upsert: List<Contact>,
    val delete: List<String>,
    val initial: Boolean,
    val latestEventId: Ulid?,
) {
    val empty
        get() = upsert.isEmpty() && delete.isEmpty() && latestEventId == null && !initial
}
