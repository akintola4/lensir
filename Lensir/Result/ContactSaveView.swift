//
//  ContactSaveView.swift
//  Lensir
//
//  The system's new-contact card, filled in from the code. Nothing is saved
//  until you tap Done in it.
//

import Contacts
import ContactsUI
import SwiftUI

struct ContactSaveView: UIViewControllerRepresentable {
    var contact: Contact
    var onFinish: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = CNContactViewController(forNewContact: Self.cnContact(contact))
        controller.delegate = context.coordinator
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            onFinish()
        }
    }

    static func cnContact(_ contact: Contact) -> CNMutableContact {
        let card = CNMutableContact()
        card.givenName = contact.givenName
        card.familyName = contact.familyName
        if contact.givenName.isEmpty, contact.familyName.isEmpty, !contact.formattedName.isEmpty {
            card.givenName = contact.formattedName
        }
        card.organizationName = contact.organization
        card.jobTitle = contact.jobTitle
        card.phoneNumbers = contact.phones.map { CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: $0)) }
        card.emailAddresses = contact.emails.map { CNLabeledValue(label: CNLabelWork, value: $0 as NSString) }
        card.urlAddresses = contact.urls.map { CNLabeledValue(label: CNLabelURLAddressHomePage, value: $0 as NSString) }
        if !contact.address.isEmpty {
            let address = CNMutablePostalAddress()
            address.street = contact.address
            card.postalAddresses = [CNLabeledValue(label: CNLabelWork, value: address)]
        }
        // The note stays out: writing it needs the Contacts notes entitlement.
        return card
    }
}
