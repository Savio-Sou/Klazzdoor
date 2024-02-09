contract ZKGlassdor {
    use dep::aztec::{
        context::{ PrivateContext, Context },
        note::{
            note_header::NoteHeader,
            note_getter_options::NoteGetterOptions,
            utils as note_utils,
        },
        protocol_types::{ address::AztecAddress, abis::function_selector::FunctionSelector },
        state_vars::{ set::Set, public_state::PublicState },
    };
    use dep::address_note::{
            address_note::{
                AddressNote,
                ADDRESS_NOTE_LEN,
            },
    };

    struct Storage {
        reviewers: Set<AddressNote>,
        reviews: PublicState<Field>,
    }

    #[aztec(private)]
    fn constructor() {
    }

    #[aztec(private)]
    fn post_review(content: Field) {
        // First we must check that the sender is in the set of reviewers. For that, we fetch a note
        // in the set that includes their address.
        let sender = context.msg_sender().to_field();
        let opts = NoteGetterOptions::new().select(0, sender, Option::none());
        let note = storage.reviewers.get_notes(opts)[0].unwrap();

        // AddressNote has both an address and an owner. In this application all notes are created with 
        // these two fields being the same, but for completeness we check that this is the case.
        assert(note.address == note.owner);

        // We now remove the note from the set by emitting a nullifier. Note that only the owner of the
        // note can emit this nullifier as it requires a secret nullifier key associated to their account.
        // This means that even if we had not checked before that the AddressNote belongs to the sender,
        // they'd still not be able to emit a nullifier and produce a valid proof.
        storage.reviewers.remove(note);

        // We can now call the public function. The content of the review will be publicly available, but
        // no information about the sender of the review will be revealed.
        context.call_public_function(
            context.this_address(),
            FunctionSelector::from_signature("_publish_review((Field))"),
            [content]
        );
    }

    #[aztec(public)]
    internal fn _publish_review(content: Field) {
        // TODO: write to an array
        storage.reviews.write(content);
    }

    unconstrained fn compute_note_hash_and_nullifier(
        contract_address: AztecAddress,
        nonce: Field,
        storage_slot: Field,
        serialized_note: [Field; ADDRESS_NOTE_LEN]
    ) -> pub [Field; 4] {
        let note_header = NoteHeader::new(contract_address, nonce, storage_slot);
        note_utils::compute_note_hash_and_nullifier(AddressNote::deserialize_content, note_header, serialized_note)
    }
}