//
//  Brands.swift
//  Lensir
//
//  The sites people get tricked into thinking they're on: Nigerian banks,
//  fintechs and services first, then the global ones. Each brand lists the
//  names a fake would borrow and the domains that really belong to it.
//  Also here: link shorteners, and the domain endings that take two labels
//  (gov.ng, co.uk) or hand out free subdomains (vercel.app).
//

nonisolated struct Brand: Equatable, Sendable {
    /// The names a lookalike would imitate, lower-case.
    var names: [String]
    /// Registrable domains the brand owns. The first is the one people know.
    var domains: [String]

    var mainDomain: String { domains[0] }

    /// Trades in many countries, so its name on a country ending (amazon.de)
    /// is probably real.
    var international: Bool

    init(_ names: [String], _ domains: [String], international: Bool = false) {
        self.names = names
        self.domains = domains
        self.international = international
    }
}

nonisolated enum Brands {
    static let all: [Brand] = [
        // Nigerian payments and fintech
        Brand(["paystack"], ["paystack.com", "paystack.co"]),
        Brand(["flutterwave"], ["flutterwave.com", "flutterwavego.com"]),
        Brand(["opay"], ["opayweb.com", "opay-inc.com", "opaycheckout.com"]),
        Brand(["palmpay"], ["palmpay.com", "palmpay.ng"]),
        Brand(["moniepoint"], ["moniepoint.com", "teamapt.com"]),
        Brand(["kuda", "kudabank"], ["kuda.com", "kudabank.com"]),
        // Banks
        Brand(["gtbank", "gtco"], ["gtbank.com", "gtco.com"]),
        Brand(["accessbankplc", "accessbank"], ["accessbankplc.com"]),
        Brand(["zenithbank"], ["zenithbank.com"]),
        Brand(["firstbanknigeria"], ["firstbanknigeria.com", "firstbankgroup.com"]),
        Brand(["ubagroup"], ["ubagroup.com"]),
        Brand(["stanbicibtc"], ["stanbicibtc.com", "stanbicibtcbank.com"]),
        Brand(["fidelitybank"], ["fidelitybank.ng", "fidelitybank.com"]),
        Brand(["sterlingbank"], ["sterling.ng"]),
        Brand(["wemabank"], ["wemabank.com"]),
        Brand(["alat"], ["alat.ng"]),
        // Shopping, telecoms, TV, power, government
        Brand(["jumia"], ["jumia.com.ng", "jumia.com"], international: true),
        Brand(["konga"], ["konga.com"]),
        Brand(["mtn", "mtnonline"], ["mtn.ng", "mtn.com", "mtnonline.com"], international: true),
        Brand(["airtel"], ["airtel.com.ng", "airtel.com", "airtel.africa", "airtel.in"], international: true),
        Brand(["glo", "gloworld"], ["gloworld.com"]),
        Brand(["dstv"], ["dstv.com"]),
        Brand(["gotv", "gotvafrica"], ["gotvafrica.com"]),
        Brand(["ikejaelectric"], ["ikejaelectric.com"]),
        Brand(["ekedp"], ["ekedp.com"]),
        Brand(["jamb"], ["jamb.gov.ng"]),
        Brand(["firs"], ["firs.gov.ng"]),
        Brand(["nimc"], ["nimc.gov.ng"]),
        // Global
        Brand(["paypal"], ["paypal.com", "paypal.me"], international: true),
        Brand(["apple"], ["apple.com", "apple.co"], international: true),
        Brand(["icloud"], ["icloud.com"]),
        Brand(["google"], ["google.com", "google.com.ng", "google.co.uk", "goo.gle", "g.co"], international: true),
        Brand(["gmail"], ["gmail.com"]),
        Brand(["whatsapp"], ["whatsapp.com", "whatsapp.net", "wa.me"]),
        Brand(["instagram"], ["instagram.com"]),
        Brand(["facebook"], ["facebook.com", "fb.com", "facebook.net", "facebookmail.com", "fb.me"]),
        Brand(["microsoft"], ["microsoft.com", "microsoftonline.com", "live.com", "office.com"], international: true),
        Brand(["netflix"], ["netflix.com"]),
        Brand(["amazon"], ["amazon.com", "amazon.co.uk", "amzn.to"], international: true),
        Brand(["binance"], ["binance.com"]),
    ]

    /// Real words and real sites one typo away from a brand, which must not
    /// be flagged: cloud (icloud), finance (binance), paypay (paypal).
    static let nearMissAllowList: Set<String> = [
        "cloud", "finance", "paypay", "apply", "amazing", "googel", "konica", "zenith",
    ]

    /// The brand that owns this registrable domain, if any.
    static func owner(of registrableDomain: String) -> Brand? {
        all.first { $0.domains.contains(registrableDomain) }
    }

    static let shorteners: Set<String> = [
        "bit.ly", "bitly.com", "tinyurl.com", "t.co", "goo.gl", "ow.ly", "is.gd", "buff.ly",
        "cutt.ly", "rebrand.ly", "shorturl.at", "rb.gy", "tiny.cc", "s.id", "v.gd", "t.ly",
        "bl.ink", "short.io", "lnkd.in", "qrco.de", "bit.do", "shorte.st", "adf.ly", "x.co",
        "tr.im", "soo.gd", "clck.ru", "u.to", "q-r.to", "shorturl.asia", "tiny.one", "rb.gy",
        "linkin.bio", "qr.page", "l.ead.me", "urlz.fr", "surl.li",
    ]

    /// Endings that take two labels, so the site name is the label before them.
    static var twoLabelSuffixes: Set<String> { countrySuffixes.union(hostingSuffixes) }

    static let countrySuffixes: Set<String> = [
        "com.ng", "org.ng", "gov.ng", "edu.ng", "net.ng", "name.ng", "mil.ng", "sch.ng", "mobi.ng",
        "co.uk", "org.uk", "gov.uk", "ac.uk", "co.za", "org.za", "gov.za", "com.gh", "gov.gh",
        "edu.gh", "co.ke", "or.ke", "go.ke", "com.au", "net.au", "org.au", "co.in", "gov.in",
        "co.jp", "com.br", "com.cn", "co.nz", "com.eg", "com.tr", "com.mx", "co.id", "com.sg",
        "com.my", "com.ph", "co.tz", "co.ug", "com.pk", "co.il", "com.sa", "com.ar",
    ]

    /// Free hosting: every subdomain is a different person's site.
    static let hostingSuffixes: Set<String> = [
        "github.io", "vercel.app", "netlify.app", "web.app", "firebaseapp.com", "blogspot.com",
        "pages.dev", "workers.dev", "herokuapp.com", "wixsite.com", "glitch.me", "ngrok.io",
        "ngrok-free.app", "azurewebsites.net", "appspot.com", "weebly.com", "myshopify.com",
        "square.site", "carrd.co", "framer.website", "webflow.io", "repl.co", "onrender.com",
        "000webhostapp.com", "godaddysites.com", "sites.google.com",
    ]
}
