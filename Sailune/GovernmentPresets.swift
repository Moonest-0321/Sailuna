import SwiftUI

struct GovernmentPresetSection: Identifiable, Equatable {
    let title: String
    let content: String

    var id: String { title }
}

struct GovernmentPreset: Identifiable, Equatable {
    let id: UUID
    let title: String
    let referenceCase: String
    let referencePeriod: String
    let summary: String
    let sections: [GovernmentPresetSection]

    static let all: [GovernmentPreset] = [
        democracy,
        communism,
        authoritarianism,
        fascism,
        imperialSystem,
        federalism,
        republicanism,
        colonialRule
    ]

    static func preset(id: UUID?) -> GovernmentPreset? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    static func matching(_ term: WorldTerm) -> GovernmentPreset? {
        all.first { preset in
            term.name == preset.title
                && term.termCategory == WorldTermCategory.institution.rawValue
                && term.termDescription == preset.summary
                && term.detailedDescription == preset.coreDefinitionText
                && term.operationAndExpression == preset.operationText
                && term.limitationsAndExceptions == preset.limitationsText
                && term.worldImpact == preset.worldImpactText
        }
    }

    func apply(to term: WorldTerm) {
        term.name = title
        term.alternateNames = referenceCase
        term.termCategory = WorldTermCategory.institution.rawValue
        term.termDescription = summary
        term.detailedDescription = coreDefinitionText
        term.operationAndExpression = operationText
        term.limitationsAndExceptions = limitationsText
        term.worldImpact = worldImpactText
        term.usageExamples = nil
        term.notes = nil
    }

    private var coreDefinitionText: String { text(for: 0...3) }
    private var operationText: String { text(for: 4...11) }
    private var limitationsText: String { text(for: 14...14) }
    private var worldImpactText: String { text(for: 12...13) + "\n\n" + text(for: 15...15) }

    private func text(for range: ClosedRange<Int>) -> String {
        range.map { index in
            let section = sections[index]
            return "【\(section.title)】\n\(section.content)"
        }.joined(separator: "\n\n")
    }

    private static func section(_ title: String, _ content: String) -> GovernmentPresetSection {
        GovernmentPresetSection(title: title, content: content)
    }

    static let democracy = GovernmentPreset(
        id: UUID(uuidString: "8D0C8D5A-3E4D-4A71-9B17-000000000001")!,
        title: "民主",
        referenceCase: "英國西敏制",
        referencePeriod: "2011 年《內閣手冊》制度基線",
        summary: "以定期競爭選舉產生下議院，政府必須維持下議院信任的議會民主。",
        sections: [
            section("主權歸屬與統治正當性", "政治正當性來自人民透過普選產生的下議院；政府能否執政取決於是否取得下議院信任。"),
            section("最高法律依據", "由國會制定法、普通法、司法判例、憲政慣例與條約共同構成，沒有單一成文憲法典。"),
            section("國家元首", "世襲君主。君主履行任命首相、召開國會與御准法案等正式職能，實際依大臣建議行事。"),
            section("政府首長／實際最高決策者", "首相是政府首長，通常為能取得下議院多數支持之政黨領袖；首相領導內閣與政府政策。"),
            section("最高行政機關", "國王陛下政府及內閣。內閣由首相主持，各部大臣共同承擔政府決策與集體責任。"),
            section("最高立法機關", "國會由君主、民選下議院與上議院組成；法案經兩院程序及御准後成為法律。"),
            section("最高司法機關", "聯合王國最高法院是民事及大部分刑事案件的終審法院；法院不能以違憲為由廢止國會制定法。"),
            section("最高監督機關", "下議院透過質詢、委員會、預算與信任表決監督政府；國家審計署及議會監察制度提供專項監督。"),
            section("領導產生、任期與接班", "下議院定期改選。君主任命最能取得下議院信任者為首相；首相辭職、失去信任或政黨更換領袖時由新領袖接任。"),
            section("選舉與政治參與", "成年公民以單一選區相對多數制選出下議院議員，多黨競爭，反對黨具有正式國會地位。"),
            section("權力制衡與問責", "政府向國會負責；下議院可拒絕預算或撤回信任。法院審查行政合法性，媒體、反對黨與選舉形成外部問責。"),
            section("軍事與治安指揮", "武裝部隊名義效忠君主，實際由文人政府透過國防大臣及首相指揮；警察依法分區運作。"),
            section("領土與地方治理", "中央為單一制主權國會，但蘇格蘭、威爾斯與北愛爾蘭獲權力下放；國會法律上保有最高權力。"),
            section("人民身分與權利", "公民享有投票、表達、結社與司法救濟；權利由制定法、普通法及人權制度保障。"),
            section("緊急權力與制度變更", "緊急權力須有國會法律依據並受審查；憲制可透過一般國會立法與慣例演進調整。"),
            section("政體專屬特色", "政府與國會多數高度結合，但首相及內閣必須持續面對國會質詢與信任約束；君主提供超黨派的國家元首。")
        ]
    )

    static let communism = GovernmentPreset(
        id: UUID(uuidString: "8D0C8D5A-3E4D-4A71-9B17-000000000002")!, title: "共產",
        referenceCase: "蘇維埃社會主義共和國聯盟", referencePeriod: "1977 年蘇聯憲法體制",
        summary: "由蘇聯共產黨領導，以社會主義公有制、蘇維埃代表機關與計畫經濟運作的聯盟國家。",
        sections: [
            section("主權歸屬與統治正當性", "憲法宣稱權力屬於人民，工人、農民與知識分子透過各級蘇維埃行使；共產黨以工人階級先鋒隊地位領導國家。"),
            section("最高法律依據", "1977 年《蘇維埃社會主義共和國聯盟憲法》，並由共產黨綱領與決議決定政治方向。"),
            section("國家元首", "最高蘇維埃主席團是集體國家元首，主席團主席代表國家履行禮儀與公布法令等職能。"),
            section("政府首長／實際最高決策者", "部長會議主席主持政府；實際最高政治領導由蘇聯共產黨中央委員會總書記掌握。"),
            section("最高行政機關", "蘇聯部長會議是最高國家行政機關，統一領導各部、國家委員會及加盟共和國行政體系。"),
            section("最高立法機關", "蘇聯最高蘇維埃由聯盟院與民族院組成；閉會期間由最高蘇維埃主席團行使持續性國家權力。"),
            section("最高司法機關", "蘇聯最高法院監督全聯盟司法；法官形式上由代表機關選舉，檢察機關統一監督法律執行。"),
            section("最高監督機關", "蘇聯總檢察長體系負責法律監督；共產黨的黨紀與幹部管理對國家機關具有實際約束力。"),
            section("領導產生、任期與接班", "代表機關以定期選舉產生；政府與司法主要職位由最高蘇維埃選任。最高領導接班實際由共產黨高層決定。"),
            section("選舉與政治參與", "候選人由共產黨及其領導的社會組織提名，選舉不形成多黨競爭；群眾透過工會、共青團等組織參與。"),
            section("權力制衡與問責", "國家機關依民主集中制運作，下級服從上級；正式問責由蘇維埃、檢察與黨組織進行，不採競爭政黨制衡。"),
            section("軍事與治安指揮", "武裝力量由國防部與最高國家機關指揮，並受共產黨政治領導；國家安全機關負責情報與政權安全。"),
            section("領土與地方治理", "由加盟共和國組成的聯邦聯盟；共和國設有自己的蘇維埃與政府，但重大政策由聯盟中央及共產黨體系統一。"),
            section("人民身分與權利", "憲法列舉工作、教育、醫療與文化等社會權利，也規定勞動、保衛祖國及遵守社會主義秩序等義務。"),
            section("緊急權力與制度變更", "最高蘇維埃負責修改憲法與決定重大國家事項；實際制度變更須先取得共產黨最高領導機關同意。"),
            section("政體專屬特色", "黨與國家機關平行存在：憲法機關負責正式決議，共產黨透過幹部任命、政策與組織紀律主導實際政治。")
        ]
    )

    static let authoritarianism = GovernmentPreset(
        id: UUID(uuidString: "8D0C8D5A-3E4D-4A71-9B17-000000000003")!, title: "威權",
        referenceCase: "佛朗哥統治下的西班牙", referencePeriod: "1967 年《國家組織法》施行後",
        summary: "以國家元首個人權威、有限代表機關與受控制政治參與維持的個人威權體制。",
        sections: [
            section("主權歸屬與統治正當性", "政權以內戰勝利、國家統一、秩序、天主教傳統與佛朗哥的終身領導作為正當性來源。"),
            section("最高法律依據", "由多部《王國基本法》構成制度基礎，其中 1967 年《國家組織法》整合國家機關。"),
            section("國家元首", "國家元首佛朗哥擁有最高政治與軍事權力，任期終身，並掌握重要任命與法律批准權。"),
            section("政府首長／實際最高決策者", "政府首長主持部長會議；1973 年以前由佛朗哥兼任，此後職位分離，但最高決策仍由國家元首掌握。"),
            section("最高行政機關", "部長會議負責行政，由政府首長主持；部長由國家元首任命並在其權威下執行政策。"),
            section("最高立法機關", "西班牙議會提供法案審議與諮詢，成員來自職務代表、家庭代表與法團體系，不是自由多黨議會。"),
            section("最高司法機關", "最高法院位於普通法院體系頂端；司法受基本法與行政權框架限制，不能形成對國家元首的實質制衡。"),
            section("最高監督機關", "王國委員會向國家元首提供高級任命與制度諮詢；國民運動體系負責政治整合與忠誠控制。"),
            section("領導產生、任期與接班", "佛朗哥為終身國家元首並有權指定王位繼承人；高級職位以任命為主，接班依基本法及指定程序進行。"),
            section("選舉與政治參與", "禁止自由政黨競爭，政治參與被納入家庭、市鎮、工團與國民運動等官方渠道。"),
            section("權力制衡與問責", "議會及諮詢機關權力有限；行政、軍事與政治任命集中於國家元首，公開反對活動受壓制。"),
            section("軍事與治安指揮", "國家元首兼任武裝力量最高統帥；軍隊、國民警衛隊、警察與情報機關是政權維持的重要支柱。"),
            section("領土與地方治理", "採高度中央集權的單一制，地方行政長官由中央控制，區域民族自治受到限制。"),
            section("人民身分與權利", "基本法列出部分權利，但結社、言論、罷工與政治組織受國家秩序及反顛覆法律嚴格限制。"),
            section("緊急權力與制度變更", "國家元首可動用非常權力；基本法及重大制度變更透過受控議會、國家元首批准與公民投票完成。"),
            section("政體專屬特色", "保留議會、法院與政府等國家外形，但政治競爭和領導更替受限，實際權力集中於終身領袖。")
        ]
    )

    static let fascism = GovernmentPreset(
        id: UUID(uuidString: "8D0C8D5A-3E4D-4A71-9B17-000000000004")!, title: "法西斯",
        referenceCase: "墨索里尼統治下的義大利王國", referencePeriod: "1939～1943 年",
        summary: "由法西斯領袖、單一政黨、國家法團與群眾動員組成的極權化國家。",
        sections: [
            section("主權歸屬與統治正當性", "政權宣稱國家與民族整體高於個人，領袖代表國家意志；革命式奪權、民族復興與戰爭動員構成正當性。"),
            section("最高法律依據", "《阿爾貝蒂諾法典》名義保留，但 1925 年後的法西斯法律、法西斯大委員會決議與領袖命令支配制度。"),
            section("國家元首", "義大利國王仍是法定國家元首，保留任命首相與軍事統帥等王權，但日常政治被法西斯政權架空。"),
            section("政府首長／實際最高決策者", "墨索里尼以領袖及政府首長身分掌握實際最高權力，控制政府、法西斯黨、宣傳與重大政策。"),
            section("最高行政機關", "部長會議在政府首長領導下執行政策；各部、地方行政長官及黨組織共同推動中央命令。"),
            section("最高立法機關", "國會由王國參議院與法團與束棒院組成；後者由法西斯黨與法團組織產生，不經自由競爭選舉。"),
            section("最高司法機關", "普通司法體系保留，政治案件另受保衛國家特別法庭處理，司法服從政權安全與法西斯法律。"),
            section("最高監督機關", "法西斯大委員會是黨國最高政治機關，決定政權、黨、王位繼承及重大國家事項。"),
            section("領導產生、任期與接班", "國王形式上任命政府首長；法西斯大委員會影響繼任名單。領袖沒有競爭性任期或正常輪替機制。"),
            section("選舉與政治參與", "其他政黨被禁止，政治參與透過國家法西斯黨、青年、婦女、工會與法團組織進行。"),
            section("權力制衡與問責", "自由議會、政黨競爭與獨立媒體被消除；國王與法西斯大委員會仍保有少數正式制約，並在 1943 年促成領袖下台。"),
            section("軍事與治安指揮", "國王名義為最高統帥，領袖掌握戰爭政策；正規軍、警察、秘密警察與法西斯民兵共同維持統治。"),
            section("領土與地方治理", "中央集權單一制，地方由中央任命的行政長官管理；殖民地另受帝國及軍事行政控制。"),
            section("人民身分與權利", "個人權利服從國家與民族利益；言論、結社及勞工組織被納入黨國控制，少數族群遭受排斥與迫害。"),
            section("緊急權力與制度變更", "行政可大量以命令治理，戰時權力進一步集中；制度變更由領袖、法西斯大委員會與受控國會推動。"),
            section("政體專屬特色", "領袖崇拜、單一政黨、法團國家、群眾組織、政治暴力與軍事化結合，企圖讓社會全面服從民族國家。")
        ]
    )

    static let imperialSystem = GovernmentPreset(
        id: UUID(uuidString: "8D0C8D5A-3E4D-4A71-9B17-000000000005")!, title: "帝制",
        referenceCase: "乾隆時期清帝國", referencePeriod: "1735～1796 年",
        summary: "皇帝以世襲、天命與征服正當性統合官僚、軍事及多族群疆域的中央集權帝國。",
        sections: [
            section("主權歸屬與統治正當性", "最高主權集中於皇帝，正當性來自皇統世襲、天命、儒家治道、軍事征服與維持天下秩序。"),
            section("最高法律依據", "皇帝諭旨具有最高效力，並以《大清律例》、會典、則例及祖宗成法治理。"),
            section("國家元首", "皇帝是唯一最高君主，兼具國家、行政、軍事、立法與最高司法權威。"),
            section("政府首長／實際最高決策者", "皇帝本人是實際最高決策者，沒有獨立於皇帝的政府首長。"),
            section("最高行政機關", "軍機處承辦最高機要與傳達諭旨，內閣處理正式文書，吏、戶、禮、兵、刑、工六部執行中央行政。"),
            section("最高立法機關", "沒有獨立立法機關；法律、條例與制度由皇帝批准，中央官署負責擬訂、彙編與執行。"),
            section("最高司法機關", "皇帝擁有終審與死刑核准權；刑部、大理寺與都察院共同處理重大案件及覆核。"),
            section("最高監督機關", "都察院及六科給事中監察官員、彈劾違失並審查行政；監督權最終隸屬皇帝。"),
            section("領導產生、任期與接班", "皇位由愛新覺羅皇族世襲，皇帝在位終身；乾隆時期採秘密建儲，由皇帝預定繼承人。"),
            section("選舉與政治參與", "沒有全民選舉。官僚主要經科舉、薦舉、捐納及旗人體系進入政府，人民不直接選任中央統治者。"),
            section("權力制衡與問責", "官僚以奏摺、會議、監察與祖宗成法提供制度性約束，但皇帝保有最終裁決權。"),
            section("軍事與治安指揮", "皇帝是最高軍事統帥，八旗為皇權核心軍事力量，綠營及地方武力負責廣域防務與治安。"),
            section("領土與地方治理", "內地以省、府、州、縣官僚治理；邊疆另採將軍、辦事大臣、盟旗、土司及藩部等差異制度。"),
            section("人民身分與權利", "人民主要以臣民身分承擔納稅、徭役與守法義務；旗民、族群、性別及身分階序適用不同規範。"),
            section("緊急權力與制度變更", "皇帝可下特旨處理戰爭、災荒、叛亂與官制調整；制度變更不需代表機關批准。"),
            section("政體專屬特色", "皇帝透過高度文官化的中央行政統治龐大疆域，同時對不同區域採取差異治理，以維持多族群帝國。")
        ]
    )

    static let federalism = GovernmentPreset(
        id: UUID(uuidString: "8D0C8D5A-3E4D-4A71-9B17-000000000006")!, title: "聯邦制",
        referenceCase: "美利堅合眾國", referencePeriod: "1992 年第二十七修正案生效後的憲政架構",
        summary: "聯邦政府與各州分別具有憲法保障的治理權，並由成文憲法及最高法院處理權限界線。",
        sections: [
            section("主權歸屬與統治正當性", "憲法以人民為主權來源；人民同時透過聯邦與州的憲政機關行使政治權力。"),
            section("最高法律依據", "《美國憲法》及其修正案是全國最高法律，聯邦法律與條約在憲法授權範圍內優先。"),
            section("國家元首", "總統是國家元首，代表聯邦處理外交、禮儀與國家象徵職能。"),
            section("政府首長／實際最高決策者", "總統同時是政府首長與聯邦行政部門最高決策者，不另設總理。"),
            section("最高行政機關", "行政權屬於總統；總統透過副總統、內閣各部、行政機關及總統行政辦公室執行法律。"),
            section("最高立法機關", "國會由按人口選出的眾議院與每州平等代表的參議院組成，兩院同意後送總統簽署。"),
            section("最高司法機關", "聯邦最高法院是最高司法機關，可在具體案件中審查聯邦及州法律是否符合憲法。"),
            section("最高監督機關", "國會透過調查、預算、任命同意與彈劾監督行政；政府問責局等機關提供審計與調查。"),
            section("領導產生、任期與接班", "總統經各州選舉人團產生，任期四年，最多當選兩次；副總統及法定順位處理死亡、辭職或失能接班。"),
            section("選舉與政治參與", "聯邦及州定期舉行競爭選舉；選舉由州及地方管理，實際政治以兩大政黨競爭為主。"),
            section("權力制衡與問責", "總統否決、國會覆議與彈劾、參議院同意任命、法院司法審查及聯邦選舉彼此制衡。"),
            section("軍事與治安指揮", "總統為武裝力量總司令，國會掌握宣戰、軍費與軍事立法；州長在一定範圍內指揮州國民兵。"),
            section("領土與地方治理", "聯邦僅行使憲法授予權力；未授予聯邦且未禁止各州行使的權力保留給州或人民。"),
            section("人民身分與權利", "人民同時是美國與所居州的公民；權利法案及後續修正案約束政府，州也可提供額外保障。"),
            section("緊急權力與制度變更", "緊急權力來自憲法與國會法律並受法院審查；修憲須國會或各州提案並由四分之三州批准。"),
            section("政體專屬特色", "參議院的州平等代表、州自主法律體系與最高法院的聯邦爭議裁判，使構成州不只是中央行政區。")
        ]
    )

    static let republicanism = GovernmentPreset(
        id: UUID(uuidString: "8D0C8D5A-3E4D-4A71-9B17-000000000007")!, title: "共和制",
        referenceCase: "法蘭西第五共和國", referencePeriod: "1962 年總統直選修憲後",
        summary: "由民選總統擔任國家元首、總理領導政府並向國會負責的半總統共和制度。",
        sections: [
            section("主權歸屬與統治正當性", "國家主權屬於人民，人民透過代表及公民投票行使；共和國以普選與憲法作為權力正當性。"),
            section("最高法律依據", "1958 年《第五共和國憲法》、憲法序言所援引的人權文件及憲法委員會確認的憲法規範。"),
            section("國家元首", "共和國總統由公民直接選舉，保障憲法與國家延續，主持部長會議並在外交、國防及制度運作上具有重要權力。"),
            section("政府首長／實際最高決策者", "總理領導政府行動；總統掌握重要政治方向。同黨執政時總統居主導，政府仍須對國民議會負責。"),
            section("最高行政機關", "政府由總理及各部長組成，決定並執行國家政策；部長會議由總統主持。"),
            section("最高立法機關", "國會由直接選舉的國民議會與間接選舉的參議院組成；兩院審議法律，特定僵局由國民議會作最後決定。"),
            section("最高司法機關", "司法法院以最高法院為終審，行政法院以國務院為最高機關；兩套法院分別處理私人及行政爭議。"),
            section("最高監督機關", "憲法委員會審查法律與選舉是否符合憲法；審計法院監督公共財政。"),
            section("領導產生、任期與接班", "總統由兩輪直接選舉產生，任期五年且不得連續超過兩任；總統任命總理，總統出缺時由參議院議長代理。"),
            section("選舉與政治參與", "總統、國民議會與地方機關均有競爭選舉；政黨自由組成，公民投票可直接決定特定制度或政策議題。"),
            section("權力制衡與問責", "政府受國民議會信任與不信任案約束；總統可解散國民議會，憲法委員會可阻止違憲法律。"),
            section("軍事與治安指揮", "總統是武裝力量統帥並主持國防會議；政府及總理負責國防政策與行政執行。"),
            section("領土與地方治理", "共和國為權力下放的單一制，市鎮、省與大區由民選機關治理，但不具有聯邦州的主權地位。"),
            section("人民身分與權利", "所有公民在法律前平等；人權與公民權宣言及憲法序言保障自由、平等、世俗與社會權利。"),
            section("緊急權力與制度變更", "總統在國家制度受嚴重威脅時可行使憲法非常權力；修憲須國會兩院通過後交公民投票或國會聯席會議批准。"),
            section("政體專屬特色", "非世襲的民選總統與向國會負責的政府並存，使共和國同時具有強勢元首和議會責任政治。")
        ]
    )

    static let colonialRule = GovernmentPreset(
        id: UUID(uuidString: "8D0C8D5A-3E4D-4A71-9B17-000000000008")!, title: "殖民統治",
        referenceCase: "英屬印度", referencePeriod: "1935 年《印度政府法》施行至 1947 年",
        summary: "英國王室透過印度事務大臣、總督與殖民官僚治理印度，並在有限自治下保留宗主國最高權力。",
        sections: [
            section("主權歸屬與統治正當性", "主權屬於英國王室與英國國會；殖民統治以王室法令、帝國法律及維持秩序與治理能力自我正當化。"),
            section("最高法律依據", "英國國會制定的 1935 年《印度政府法》及相關王室命令、印度法令與殖民行政規章。"),
            section("國家元首", "英國君主是印度皇帝及最高法定主權者，由在英國的王室與政府行使帝國權力。"),
            section("政府首長／實際最高決策者", "印度總督兼副王代表英國君主主持殖民政府；英國內閣與印度事務大臣掌握最終帝國政策。"),
            section("最高行政機關", "印度總督行政會議管理中央行政；總督保有保留權力、否決權及在緊急情況下直接治理的權限。"),
            section("最高立法機關", "中央立法機關設聯邦議會與國務院，但總督可批准、否決、保留法案或自行發布條例。"),
            section("最高司法機關", "印度聯邦法院處理聯邦與憲法爭議，仍可向倫敦樞密院司法委員會上訴。"),
            section("最高監督機關", "英國國會、印度事務大臣及其在倫敦的行政體系監督殖民政府；印度本地代表機關權限受帝國保留事項限制。"),
            section("領導產生、任期與接班", "總督由英國君主任命，實際依英國政府建議；高級殖民官員由任命產生，不向印度全體居民負責。"),
            section("選舉與政治參與", "省與中央設有限選舉，但選舉資格受財產、教育與社群安排限制；印度政黨能參與省級治理但不能控制帝國保留權。"),
            section("權力制衡與問責", "代表機關可辯論與管理部分政策，總督、印度事務大臣與英國國會保有否決及介入權，殖民行政不受印度選民完整問責。"),
            section("軍事與治安指揮", "英屬印度軍隊由帝國軍事體系指揮，總督及英國政府控制國防；殖民警察與情報機關維持內部秩序。"),
            section("領土與地方治理", "英屬省由殖民政府直接治理，土邦由本地君主統治但受英國宗主權與駐紮官監督；省級自治受總督保留權限制。"),
            section("人民身分與權利", "印度居民是英國臣民或土邦臣民，政治權利不等同英國本土公民；法律地位、選舉與公共職位存在種族及身分差異。"),
            section("緊急權力與制度變更", "總督可在憲政機關失效時接管省政並發布條例；根本制度變更由英國國會立法決定。"),
            section("政體專屬特色", "本地代表制度與自治機關存在，但主權、軍事、外交及最終否決權留在宗主國，形成不對等的雙層統治。")
        ]
    )
}

struct GovernmentPresetCatalogView: View {
    let allowsSelection: Bool
    let selectedID: UUID?
    let onSelect: ((GovernmentPreset?) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var displayedPresetID: UUID?

    init(allowsSelection: Bool = false, selectedID: UUID? = nil, onSelect: ((GovernmentPreset?) -> Void)? = nil) {
        self.allowsSelection = allowsSelection
        self.selectedID = selectedID
        self.onSelect = onSelect
        _displayedPresetID = State(initialValue: selectedID ?? GovernmentPreset.all.first?.id)
    }

    private var displayedPreset: GovernmentPreset? {
        GovernmentPreset.preset(id: displayedPresetID)
    }

    var body: some View {
        NavigationSplitView {
            List(GovernmentPreset.all, selection: $displayedPresetID) { preset in
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.title).font(.headline)
                    Text(preset.referenceCase).font(.caption).foregroundStyle(.secondary)
                }
                .tag(preset.id)
            }
            .navigationTitle("政體")
        } detail: {
            if let displayedPreset {
                GovernmentPresetDetailView(preset: displayedPreset)
                    .safeAreaInset(edge: .bottom) {
                        if allowsSelection {
                            HStack {
                                Button("不選擇") {
                                    onSelect?(nil)
                                    dismiss()
                                }
                                Spacer()
                                Button("選擇(displayedPreset.title)") {
                                    onSelect?(displayedPreset)
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding()
                            .background(.bar)
                        }
                    }
            } else {
                ContentUnavailableView("請選擇政體", systemImage: "building.columns")
            }
        }
        .frame(minWidth: 760, minHeight: 620)
        .toolbar {
            Button("關閉") { dismiss() }
        }
    }
}

struct GovernmentPresetDetailView: View {
    let preset: GovernmentPreset

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(preset.title).font(.title2.weight(.bold))
                    Text("參考案例：\(preset.referenceCase)")
                        .font(.subheadline.weight(.semibold))
                    Text("制度年代：\(preset.referencePeriod)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(preset.summary).padding(.top, 4)
                }

                Divider()

                ForEach(preset.sections) { section in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(section.title).font(.headline)
                        Text(section.content)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle(preset.title)
    }
}
