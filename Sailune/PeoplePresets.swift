import SwiftUI

enum PeoplePresetGroup: String, CaseIterable, Identifiable {
    case realWorld = "現實族群／文化群體"
    case fictional = "虛構種族"

    var id: String { rawValue }
}

struct PeoplePresetSection: Identifiable, Equatable {
    let title: String
    let content: String

    var id: String { title }
}

/// 族群預設把現實群體視為歷史與文化形成的社會群體；不以模板判定人格、能力或價值高低。
struct PeoplePreset: Identifiable, Equatable {
    let id: UUID
    let title: String
    let group: PeoplePresetGroup
    let referenceCase: String
    let referencePeriod: String
    let summary: String
    let sections: [PeoplePresetSection]

    static let realWorld: [PeoplePreset] = [
        han,
        yamato,
        slavic,
        germanic,
        mongolian,
        southAsian,
        arab,
        persian,
        turkic,
        mande,
        swahili,
        austronesian
    ]

    static let fictional: [PeoplePreset] = [
        elf,
        dwarf,
        orc,
        dragonkin,
        merfolk,
        undead
    ]

    static var all: [PeoplePreset] { realWorld + fictional }

    static func preset(id: UUID?) -> PeoplePreset? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    static func matching(_ term: WorldTerm) -> PeoplePreset? {
        all.first { preset in
            term.name == preset.title
                && term.termCategory == WorldTermCategory.people.rawValue
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
        term.termCategory = WorldTermCategory.people.rawValue
        term.termDescription = summary
        term.detailedDescription = coreDefinitionText
        term.operationAndExpression = operationText
        term.limitationsAndExceptions = limitationsText
        term.worldImpact = worldImpactText
        term.usageExamples = nil
        term.notes = nil
    }

    private var coreDefinitionText: String { text(for: 0...2) }
    private var operationText: String { text(for: 3...8) }
    private var limitationsText: String { text(for: 9...9) }
    private var worldImpactText: String { text(for: 10...11) }

    private func text(for range: ClosedRange<Int>) -> String {
        range.map { index in
            let section = sections[index]
            return "【\(section.title)】\n\(section.content)"
        }.joined(separator: "\n\n")
    }

    private struct Seed {
        let id: UUID
        let title: String
        let referenceCase: String
        let referencePeriod: String
        let summary: String
        let origin: String
        let body: String
        let lifecycle: String
        let habitat: String
        let abilities: String
        let continuity: String
        let society: String
        let culture: String
        let language: String
        let technology: String
        let relations: String
        let prompt: String
    }

    private static func make(_ group: PeoplePresetGroup, _ seeds: [Seed]) -> [PeoplePreset] {
        seeds.map { seed in
            PeoplePreset(
                id: seed.id,
                title: seed.title,
                group: group,
                referenceCase: seed.referenceCase,
                referencePeriod: seed.referencePeriod,
                summary: seed.summary,
                sections: [
                    section("族群／種族定位與起源", seed.origin),
                    section("身體特徵與外觀", seed.body),
                    section("壽命、成長與生命週期", seed.lifecycle),
                    section("棲地、生態與生存需求", seed.habitat),
                    section("能力、限制與適應方式", seed.abilities),
                    section("成員形成與世代延續", seed.continuity),
                    section("社會組織與身份結構", seed.society),
                    section("文化、習俗與價值觀", seed.culture),
                    section("語言、文字與溝通", seed.language),
                    section("技術、資源與日常生活", seed.technology),
                    section("與其他族群的關係面向", seed.relations),
                    section("類型專屬特色與寫作提示", seed.prompt)
                ]
            )
        }
    }

    private static func section(_ title: String, _ content: String) -> PeoplePresetSection {
        PeoplePresetSection(title: title, content: content)
    }

    static let han = make(.realWorld, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000001")!, title: "漢人（漢文化圈）",
        referenceCase: "東亞漢文化圈的歷史社會", referencePeriod: "帝國時代至現代",
        summary: "以漢語文化、家族與地方社會交織形成的多樣歷史族群；內部地域、階層與信仰差異很大。",
        origin: "族群認同由歷代國家、地方社會、婚姻遷徙、教育與文字文化共同形成，並非單一血統起點。",
        body: "外觀與體質受地域、婚姻、營養與個體差異影響；不能從外貌推定方言、階層或政治立場。",
        lifecycle: "家庭、教育、服役、工作與代際照護安排生命歷程；城鄉與時代會改變成長與老年經驗。",
        habitat: "農業平原、河流流域、沿海城市與山地社會都可形成漢人社群，生活受季風、水利與城市化影響。",
        abilities: "文字教育、家族網絡與地方協作可形成優勢；人口流動、階層差異、戰亂與資源不均是限制。",
        continuity: "血緣、收養、婚姻、戶籍、學校與地方認同共同延續成員資格；不同時代的認同邊界會改變。",
        society: "宗族、村社、城市行會、學校、公司與國家制度交錯，身份可同時具有地方、職業與國族層次。",
        culture: "節令、祭祖、飲食、禮俗、書寫與教育傳統多樣並存；地方實踐不應被單一經典概括。",
        language: "漢語各方言與共同語並存，漢字及其變體提供跨地域書寫；語言使用常與教育、媒體和遷徙相連。",
        technology: "農耕、水利、手工業、印刷、商業與現代工業在不同時期組合；技術傳承同時依靠家庭、師徒與制度教育。",
        relations: "與周邊民族、移民、殖民秩序及國家邊界的關係隨時代改變；同一群體內也可能有語言與階層張力。",
        prompt: "可從地方與國家、家族與個人、傳統與現代化之間的多重身份切入，保留內部差異。"
    )]) [0]

    static let yamato = make(.realWorld, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000002")!, title: "大和／和人（日本列島）",
        referenceCase: "日本列島的和人社會", referencePeriod: "古代國家形成至現代",
        summary: "以日本列島歷史、日語文化與國家制度形成的主要族群認同；北海道、琉球與移民經驗不應被抹平。",
        origin: "認同由列島聚落、國家建構、語言教育、婚姻與現代國民制度逐步塑造，並非純粹血統。",
        body: "身體與外觀存在個體及地域差異，不能由外貌推斷文化忠誠、性格或社會位置。",
        lifecycle: "學校、公司、家庭與高齡照護構成現代生命節奏；世代差異與都市／地方差異明顯。",
        habitat: "島嶼、山地、沿海港市與寒暖不同的列島環境塑造聚落、災害應對與食物系統。",
        abilities: "高密度協作、災害應變與制度化教育可形成能力；島嶼資源、人口老化與中心地方落差是限制。",
        continuity: "家庭、學校、戶籍、地方祭祀與國民身份共同延續；琉球、阿伊努與移民歷史提醒認同並非單一。",
        society: "皇室、政府、企業、學校、地方社群與社團組織交織，正式制度與非正式協調並存。",
        culture: "季節節慶、祭典、工藝、飲食、美學與集體禮儀多樣發展；不同地方保有各自脈絡。",
        language: "日語共同語與地方方言並存，漢字、平假名與片假名共同使用；語域和敬語標示社會關係。",
        technology: "稻作、工藝、印刷、近代工業、鐵路與電子產業在不同階段累積，傳統工藝與高科技可並存。",
        relations: "列島內部與鄰近東亞社會的交流、帝國歷史、移民與少數族群權利都會影響身份協商。",
        prompt: "可從地方祭典、組織責任、災害記憶與個人選擇之間的張力切入，不把整個社會寫成單一性格。"
    )]) [0]

    static let slavic = make(.realWorld, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000003")!, title: "斯拉夫文化群體",
        referenceCase: "東、西、南斯拉夫語族社會的歷史交集", referencePeriod: "中世紀至現代",
        summary: "由相近語族、遷徙與區域歷史交織形成的多個文化群體，不是單一國家或單一民族。",
        origin: "族名、語言、宗教、帝國邊界與近代民族建構共同塑造斯拉夫認同，各分支有不同歷史。",
        body: "地域、婚姻、營養與個體差異遠大於任何刻板外貌；外觀不能決定語言或政治認同。",
        lifecycle: "農村、城市、工業化、戰爭與移民經驗使世代生命歷程差異很大。",
        habitat: "從森林、草原、河谷到海岸與城市，氣候和帝國疆界塑造多種生活方式。",
        abilities: "多語接觸、地方互助與適應不同政權可成為社會資源；戰亂、邊界變更與經濟不平等是限制。",
        continuity: "語言、東正教或天主教傳統、家庭、地方記憶與國籍共同延續身份；同語族不等於同政治共同體。",
        society: "村社、教會、帝國行政、民族國家與移民網絡並存，階層和地區差異不可省略。",
        culture: "季節節慶、史詩、音樂、木工、飲食與宗教儀式各地不同，口述與書寫傳統互補。",
        language: "斯拉夫語族內有東、西、南支，文字可能使用西里爾或拉丁字母；互通程度受教育與政治影響。",
        technology: "農業、林業、工業、鐵路與現代資訊技術依地區發展，技術常沿帝國與國家網絡傳播。",
        relations: "與日耳曼、突厥、波羅的、芬烏戈爾及鄰近群體的交流和衝突會重塑邊界。",
        prompt: "可從語言相近卻國界不同、帝國記憶與現代國族之間的身份錯位切入。"
    )]) [0]

    static let germanic = make(.realWorld, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000004")!, title: "日耳曼文化群體",
        referenceCase: "北日耳曼與西日耳曼語族社會", referencePeriod: "古代部落至現代國家",
        summary: "由日耳曼語族、北海與中歐歷史、宗教改革及近代國家建構交織成的多個文化群體。",
        origin: "語族、地方政治、基督宗教、城市商業與近代民族國家共同塑造認同，不能簡化為血統。",
        body: "北歐、中歐與海外社群存在廣泛個體差異；外貌不能推定文化或制度偏好。",
        lifecycle: "家庭、教會、學校、工業城市與福利制度塑造不同世代，移民使生活經驗更加多元。",
        habitat: "森林、農地、北海沿岸、山地與高度城市化區域形成不同資源與居住方式。",
        abilities: "航海、工藝、制度協作與工業技能可能成為社會資源；氣候、資源與戰爭記憶構成限制。",
        continuity: "語言、地方社群、教派、家庭、國籍與職業身份共同延續，沒有單一的日耳曼成員標準。",
        society: "村鎮、城市行會、教會、國家、企業與福利機構交錯，自治與中央治理可能同時存在。",
        culture: "季節節慶、法律傳統、音樂、工藝、飲食與海洋記憶依地區變化，近代移民帶來新層次。",
        language: "北日耳曼與西日耳曼語言分化明顯，書寫傳統和標準化教育影響跨地交流。",
        technology: "航海、冶金、印刷、工業化、電氣與資訊技術在不同地區累積，制度和市場同樣重要。",
        relations: "與斯拉夫、凱爾特、薩米、波羅的及殖民地人民的互動深刻影響現代身份與歷史記憶。",
        prompt: "可從地方自治與國家規範、工業財富與殖民遺產、語言分化與共同身份切入。"
    )]) [0]

    static let mongolian = make(.realWorld, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000005")!, title: "蒙古族群",
        referenceCase: "蒙古高原遊牧與城市社會", referencePeriod: "帝國時代至現代",
        summary: "以蒙古語族、草原生計、部落記憶與現代國家共同形成的多個蒙古族群社會。",
        origin: "部落聯盟、草原政治、帝國歷史、宗教與現代國界共同塑造認同；跨境社群仍保有多樣性。",
        body: "外貌與體質受地域、婚姻與生活條件影響，不能作為身份或能力判定。",
        lifecycle: "牧季移動、城市教育、軍政制度與現代勞動市場塑造不同生命歷程。",
        habitat: "草原、沙漠、山地與城市共同構成生活空間，水源、牧場與極端氣候是核心條件。",
        abilities: "畜牧、騎乘、環境判讀與遠距互助可形成能力；寒旱、牧場壓力與城市化是限制。",
        continuity: "家族、部落記憶、語言、宗教、國籍與城市／牧區身份共同延續成員資格。",
        society: "家庭、氏族、牧民社群、寺院、地方政府與現代企業並存，權威可能隨環境切換。",
        culture: "那達慕、長調、史詩、馬文化、奶食與帳幕生活具有地域差異，也持續都市化。",
        language: "蒙古語各方言與多種書寫傳統並存，國界和教育制度影響語言標準與跨境溝通。",
        technology: "畜牧工具、騎乘、道路、礦業、通訊與城市基礎設施共同支撐生活，季節性仍重要。",
        relations: "與漢地、突厥、俄羅斯及其他草原群體的交流、帝國記憶與邊界制度塑造現代關係。",
        prompt: "可從牧區與城市、跨境親族、資源開發與草原保育之間的取捨切入。"
    )]) [0]

    static let southAsian = make(.realWorld, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000006")!, title: "印度次大陸多民族文化群體",
        referenceCase: "印度次大陸的多語、多宗教社會", referencePeriod: "古代城市文明至現代",
        summary: "涵蓋多語、多宗教、多族群與多層級地方社會的區域型模板，不把印度次大陸視為單一民族。",
        origin: "河谷、王朝、宗教、商路、殖民治理與現代國家共同塑造多重身份，區域差異是核心。",
        body: "南亞人口高度多樣，外貌不能推定語言、種姓、宗教、階級或政治立場。",
        lifecycle: "家庭、社群、教育、婚姻、工作與城市化交織；階級、性別與地區會改變生命機會。",
        habitat: "季風平原、河谷、山地、海岸與特大城市形成不同生計，水與季風節律影響日常。",
        abilities: "多語協商、商業網絡、手工技藝與社群互助可形成資源；不平等、污染與基礎設施差距是限制。",
        continuity: "家族、宗教、語言社群、地方、種姓／社群制度與國籍共同延續身份，成員邊界常有爭議。",
        society: "村社、城市、宗教機構、商業網絡、國家與侨民共同運作，正式法律與習慣規範可能交疊。",
        culture: "節慶、飲食、音樂、舞蹈、史詩與儀式極為多樣；任何單一傳統都只能代表部分地區。",
        language: "印歐、達羅毗荼及其他語族並存，文字系統多元；通用語、地方語與英語分工隨場域改變。",
        technology: "農業、水利、紡織、航海、資訊服務與現代製造並存，技術採用受階級和地區影響。",
        relations: "宗教、語言、種姓、殖民遺產、跨境分治與移民經驗會重塑群體邊界與互動。",
        prompt: "可從多重身份同時成立、地方傳統與國家法律衝突、城市化與社群責任切入。"
    )]) [0]

    static let arab = make(.realWorld, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000007")!, title: "阿拉伯文化群體",
        referenceCase: "阿拉伯語文化圈的城市與部落社會", referencePeriod: "伊斯蘭文明形成至現代",
        summary: "以阿拉伯語、部落與城市歷史、伊斯蘭文明及近代國家形成的多個文化群體。",
        origin: "語言、宗教、商路、部落聯盟、帝國與現代國界共同塑造認同，不等於單一血統或政權。",
        body: "北非、黎凡特、阿拉伯半島與海外社群的外貌與生活差異很大，不能用刻板形象概括。",
        lifecycle: "家族、宗教教育、城市職業、部落關係與移民塑造生命歷程，戰爭和勞動流動也會重組家庭。",
        habitat: "沙漠、河谷、海岸、綠洲與都市構成多種環境，水、能源與商路是關鍵條件。",
        abilities: "多代家族互助、商業網絡、口述詩與多語交流可形成資源；乾旱、政治邊界與戰亂是限制。",
        continuity: "家族、部落、城市、宗教、語言與國籍共同延續身份，阿拉伯認同可與地方身份並存。",
        society: "家庭、部落、宗教機構、國家官僚、商業與侨民網絡交織，正式法與習慣法可能並存。",
        culture: "齋戒、節慶、待客、詩歌、音樂、飲食與服飾在地區間差異顯著，不應單一化。",
        language: "現代標準阿拉伯語與地方口語並存，文字傳統跨國共享；教育、媒體與宗教場域語域不同。",
        technology: "灌溉、航海、商貿、能源、城市建設與數位服務依地區組合，資源分配影響普及程度。",
        relations: "與柏柏爾、波斯、非洲、土耳其及歐洲社會的交流和帝國邊界持續塑造身份。",
        prompt: "可從家族責任、城市與部落、能源財富、移民與國界之間的多重關係切入。"
    )]) [0]

    static let persian = make(.realWorld, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000008")!, title: "波斯文化群體",
        referenceCase: "伊朗高原的波斯語文化社會", referencePeriod: "古代帝國至現代",
        summary: "以波斯語文學、伊朗高原歷史、帝國記憶與多族群國家交織形成的文化群體。",
        origin: "古代王朝、宗教轉變、城市網絡、波斯語教育與現代國家共同塑造認同，並非單一血統。",
        body: "伊朗高原與海外社群具有顯著地域和個體差異，外貌不能推定宗教或政治立場。",
        lifecycle: "家庭、教育、宗教、城市職業與移民經驗共同組織生命歷程，代際政治記憶可能不同。",
        habitat: "高原、山地、綠洲、裏海與海灣沿岸形成多種生計，水資源和商路影響聚落。",
        abilities: "詩文、手工藝、商業與跨區域行政傳統可形成資源；乾旱、制裁與地緣政治是限制。",
        continuity: "語言、家庭、地方、宗教、王朝記憶與國籍共同延續身份，波斯認同可跨越多種宗教。",
        society: "家庭、宗教學者、城市市集、國家官僚與海外社群交織，中央與地方權威可能拉扯。",
        culture: "新年、詩歌、園林、地毯、音樂、飲食與待客文化具有深厚傳統，地方變體持續存在。",
        language: "波斯語及其方言使用阿拉伯字母書寫，與庫德、阿塞拜疆語等語言長期接觸。",
        technology: "灌溉、建築、手工藝、石化、工程與數位服務並存，制裁和人才流動影響技術取得。",
        relations: "與阿拉伯、突厥、南亞、高加索與歐洲社會的交流和帝國記憶會重塑邊界。",
        prompt: "可從帝國記憶、宗教與世俗、海外侨民、地方語言與中央國家之間切入。"
    )]) [0]

    static let turkic = make(.realWorld, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000009")!, title: "突厥語族文化群體",
        referenceCase: "中亞、安納托利亞與西伯利亞的突厥語族社會", referencePeriod: "古代草原國家至現代",
        summary: "由突厥語族、草原與城市歷史、伊斯蘭化和近代國界形成的多個文化群體。",
        origin: "遊牧聯盟、商路、帝國、宗教與現代民族國家共同形成認同；語族相近不代表政治一致。",
        body: "跨越歐亞大陸的突厥語族群體外貌與生活高度多樣，不能以單一形象概括。",
        lifecycle: "牧業、農業、城市教育、軍政制度與移民經驗共同塑造生命歷程。",
        habitat: "草原、山谷、綠洲、海岸與都市形成不同生計，水源、牧道與商路是關鍵。",
        abilities: "騎乘、遠距貿易、多語接觸與地方互助可形成資源；邊界分割、氣候與政治壓力是限制。",
        continuity: "語言、家族、部落、宗教、城市與國籍共同延續身份，跨境親族常使邊界更複雜。",
        society: "部落聯盟、城市市集、宗教機構、國家軍政與現代企業並存，權威來源隨場域變化。",
        culture: "史詩、馬文化、音樂、毛氈、飲食與節慶各地不同，草原與城市傳統互相影響。",
        language: "突厥語族含多個分支，文字曾使用古突厥、阿拉伯、拉丁與西里爾系統，標準化受國家影響。",
        technology: "畜牧、冶金、灌溉、商路、能源與現代工業並存，技術流動常跨越多個政權。",
        relations: "與蒙古、波斯、斯拉夫、漢地、高加索與阿拉伯社會的交流持續重塑身份和政治想像。",
        prompt: "可從跨境親族、草原與城市、語言標準化及帝國遺產切入。"
    )]) [0]

    static let mande = make(.realWorld, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000010")!, title: "西非曼德文化群體",
        referenceCase: "西非曼德語族與商貿社會", referencePeriod: "中世紀西非帝國至現代",
        summary: "以曼德語族、商貿網絡、口述史與西非城市／農村社會形成的多個文化群體。",
        origin: "古代帝國、商路、伊斯蘭學術、地方社群與殖民邊界共同塑造認同，內部分支眾多。",
        body: "西非社群的外貌、宗教與生活方式多樣，不能從外觀推定階級或文化。",
        lifecycle: "家族、師徒、農牧季節、城市工作與海外移民共同安排代際生活。",
        habitat: "薩赫勒、河谷、森林邊緣與城市市場構成不同生計，降雨與土地是核心條件。",
        abilities: "商業、農耕、工藝、口述記憶與跨村互助可形成資源；乾旱、土地壓力與政治邊界是限制。",
        continuity: "家族、職業群體、語言、宗教、地方與國籍共同延續身份，社群成員資格可能有多重標準。",
        society: "村社、家族、行業群體、宗教學者、城市商人與國家行政交疊，口述權威很重要。",
        culture: "史詩、鼓樂、舞蹈、紡織、金工、節慶與飲食依地域變化，傳承常靠表演與師徒。",
        language: "曼德語族多語並存，口述傳統與拉丁或阿拉伯字母書寫互補，貿易促進語言接觸。",
        technology: "農耕、冶金、染織、商路、手機金融與城市服務共同構成生活，基礎設施差異顯著。",
        relations: "與富拉尼、阿拉伯、柏柏爾、歐洲殖民秩序及鄰近西非群體的互動塑造現代邊界。",
        prompt: "可從口述史與書寫、商旅與地方責任、城市青年與村社長者之間切入。"
    )]) [0]

    static let swahili = make(.realWorld, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000011")!, title: "東非斯瓦希里文化群體",
        referenceCase: "東非印度洋沿岸斯瓦希里城市社會", referencePeriod: "中世紀海上貿易至現代",
        summary: "以斯瓦希里語、印度洋貿易、沿岸城市與非洲、阿拉伯、波斯交流形成的多層文化群體。",
        origin: "沿海聚落、海上商貿、伊斯蘭、非洲內陸網絡與殖民國界共同形成認同。",
        body: "沿岸、島嶼與內陸社群具有多樣外貌和歷史，不能以海洋貿易想像概括所有人。",
        lifecycle: "家庭、宗教教育、港口工作、漁業、商業與跨境移民共同塑造生命節奏。",
        habitat: "珊瑚海岸、島嶼、港口、河口與內陸交通線形成不同生計，季風和海況很重要。",
        abilities: "航海、語言中介、商業與沿岸互助可形成資源；海平面、疾病、殖民遺產與基礎設施是限制。",
        continuity: "家族、城市、宗教、語言、海商網絡與國籍共同延續身份，沿岸與內陸認同可能不同。",
        society: "港口市集、家族、清真寺、漁村、商人與國家行政交織，海洋網絡穿透政治邊界。",
        culture: "海洋飲食、詩歌、建築、服飾、齋戒與節慶受多文化交流影響，各港口保有地方特色。",
        language: "斯瓦希里語以班圖語法吸收阿拉伯、波斯與其他語言詞彙，書寫與口語場域各有變體。",
        technology: "帆船、漁具、港口、商貿、通訊與現代旅遊／物流並存，季風知識仍具日常價值。",
        relations: "與阿拉伯、波斯、印度、非洲內陸和歐洲殖民政權的往來塑造身份與權力。",
        prompt: "可從港口中介、多語身份、海洋生計與殖民地界線之間切入。"
    )]) [0]

    static let austronesian = make(.realWorld, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000012")!, title: "南島海洋文化群體",
        referenceCase: "太平洋、東南亞與印度洋的南島語族社會", referencePeriod: "史前航海擴散至現代",
        summary: "以南島語族、海洋遷徙、島嶼生態與跨島親族形成的多個文化群體，不是單一民族。",
        origin: "長期航海遷徙、島嶼定居、地方王國、殖民邊界與現代國家共同塑造多重身份。",
        body: "跨越廣大海域的群體在外貌、語言與生活方式上差異很大，不能以單一島嶼形象概括。",
        lifecycle: "家族、村社、海上工作、教育、移民與季節性勞動安排不同生命歷程。",
        habitat: "珊瑚島、火山島、河口、雨林與沿海城市形成多種生計，海況和淡水是關鍵。",
        abilities: "航海、潮汐知識、漁業、農耕與跨島互助可形成資源；氣候災害、海平面與交通限制是挑戰。",
        continuity: "親族、村社、語言、土地／海域、宗教與國籍共同延續身份，移民使邊界更加流動。",
        society: "村社、酋長或長老、教會／宗教、商業、國家與海外侨民網絡並存，權威依地區不同。",
        culture: "航海歌謠、舞蹈、刺繡、船藝、飲食與祖先記憶依島嶼變化，口述傳承很重要。",
        language: "南島語族分支廣泛，語言接觸與殖民教育帶來多種書寫和雙語情境。",
        technology: "獨木舟、灌溉、梯田、漁具、港口、手機與海洋科學共同支撐生活。",
        relations: "島嶼間親族、殖民邊界、內陸族群、移民社群與海洋資源爭議會重塑身份。",
        prompt: "可從島嶼自治、移民匯款、海洋保育與祖先土地／海域責任切入。"
    )]) [0]

    static let elf = make(.fictional, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000101")!, title: "精靈",
        referenceCase: "原創長壽森林族群", referencePeriod: "架空世界的長時段社會",
        summary: "長壽、感官敏銳且與森林生態深度互動的架空族群；內部可有城市、游牧與工匠分支。",
        origin: "可設定為古老遷徙、自然共生或魔法演化的後裔，起源不自動決定善惡或政治立場。",
        body: "尖耳、纖長體態或發光瞳色只是可選外觀；體質、年齡與地域應保留個體差異。",
        lifecycle: "成長期長、成年標準可能按知識或儀式判定；長壽使記憶、代際責任與更新速度成為議題。",
        habitat: "森林、古樹城市、河谷與人工庭園都可居住，食物、光照與魔力循環限制聚落。",
        abilities: "感官、植物知識與精細工藝可能突出；長壽、低繁殖率與環境依賴也形成限制。",
        continuity: "出生、收養、契約、轉化或靈魂認可都可形成成員資格，讓血統不是唯一標準。",
        society: "氏族、林地議會、工匠院、遊俠團與學院可能並存，長者記憶與新世代改革互相拉扯。",
        culture: "季節儀式、歌謠、樹木記憶、工藝與守林倫理構成文化；不同林地可有截然不同價值。",
        language: "語言可重視長詞、歌唱或氣味／光訊號；文字可能刻在樹皮、晶體或活體媒介上。",
        technology: "活木建築、療癒、弓械、光學與生態工程構成日常，資源取得受森林承載力限制。",
        relations: "與人類、矮人、獸人或龍裔的邊界可圍繞土地、時間觀與資源責任形成，而非預設善惡。",
        prompt: "可從長壽記憶、森林承載力、傳統守護與新世代選擇之間切入。"
    )]) [0]

    static let dwarf = make(.fictional, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000102")!, title: "矮人",
        referenceCase: "原創地下工匠族群", referencePeriod: "架空世界的山脈城邦時代",
        summary: "擅長地下工程、冶金與工匠協作的架空族群；山地、地表與城市分支可各自發展。",
        origin: "可源於山脈遷徙、地下適應或古代工匠契約，起源保留不同部族的解釋。",
        body: "矮小、寬肩、鬍鬚或耐寒只是常見設計，不應把外觀直接等同力量、性別或職業。",
        lifecycle: "成長與成年可能以學徒資格、工坊責任或家族儀式衡量，壽命長短可依作者設定變化。",
        habitat: "礦山、地下城、山口與地表工坊都可居住；通風、飲水、光照和礦脈是限制。",
        abilities: "工程、金工、地層判讀與集體維修可形成優勢；封閉性、資源枯竭與塌陷是風險。",
        continuity: "家族、工坊收徒、契約認可或共同守護工程都可成為成員形成方式。",
        society: "氏族、工坊、礦主、城牆議會與商隊並存，技藝聲望未必等同政治權力。",
        culture: "鑄造誓約、祖先碑、工匠節、宴飲與地下音樂構成文化，不同城邦可以互不相同。",
        language: "複合詞、節奏敲擊與刻銘文字可成為特色；工坊術語與地表通用語可能分層。",
        technology: "冶金、機械、隧道、水力與耐熱器具支撐生活，燃料和礦脈決定工業規模。",
        relations: "與地表國家、精靈森林、商隊和礦區居民的關係可圍繞通行權、技術與環境責任展開。",
        prompt: "可從工坊傳承、礦脈所有權、地下安全與年輕人離開城邦切入。"
    )]) [0]

    static let orc = make(.fictional, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000103")!, title: "獸人",
        referenceCase: "原創多部族邊境族群", referencePeriod: "架空世界的遷徙與城寨時代",
        summary: "由多個部族、城寨與混居社群組成的架空族群；不預設野蠻、邪惡或單一政治立場。",
        origin: "起源可連結草原遷徙、邊境融合或古代災變，不同部族有各自的祖源敘事。",
        body: "獠牙、皮膚色澤、體格與感官可有廣泛變化，外觀不能決定道德或社會位置。",
        lifecycle: "成年可能由狩獵、照護、守衛、學藝或社群承認判定，家庭形式可跨部族不同。",
        habitat: "草原、森林邊境、荒地與城寨都可成為家園，水源、牧地和遷徙路線是核心。",
        abilities: "耐力、野外判讀、團隊互助與口述記憶可成為資源；資源季節性與外界歧視是限制。",
        continuity: "血緣、收養、戰友盟誓、婚姻與部族承認都可形成成員資格，族群邊界保持流動。",
        society: "部族議會、獵團、城寨、商隊與混居城市並存，領導權可能依情境輪替。",
        culture: "成年儀式、歌舞、祖靈、戰利品、照護與食物分享可構成文化，各部族有不同禁忌。",
        language: "短促口語、鼓號、手勢與多語接觸可並存；口述史與外界書寫可能互相誤讀。",
        technology: "皮革、骨木、金屬、馴獸、堡寨與回收工藝支撐日常，技術並非低階的同義詞。",
        relations: "與人類城邦、矮人礦區、精靈林地及內部部族的關係可圍繞土地、偏見與盟約發展。",
        prompt: "可從外界刻板印象與內部多樣性、邊境生存、盟誓與城市融入切入。"
    )]) [0]

    static let dragonkin = make(.fictional, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000104")!, title: "龍裔",
        referenceCase: "原創龍血與城邦混合族群", referencePeriod: "架空世界的龍族遺產時代",
        summary: "帶有龍族遺傳、契約或文化傳承的架空族群；龍血不必決定階級、能力或身份。",
        origin: "可由混血、古代契約、人工造生或龍族庇護形成，不同社群可對起源有衝突解釋。",
        body: "鱗片、角、尾、體溫與翼膜可依支系變化；外觀與能力需有代價和個體差異。",
        lifecycle: "孵化、出生、蛻變、成年試煉或契約更新都可構成生命階段，壽命不必一致。",
        habitat: "火山、荒漠、城邦、天空港或海岸都可居住，熱源、礦物與空間需求影響聚落。",
        abilities: "耐熱、飛行、吐息或記憶能力可存在，但能量消耗、體型、控制難度與法律是限制。",
        continuity: "血緣、龍契、收養、孵化院或社群認可都可形成成員資格，龍族本人未必承認所有後裔。",
        society: "氏族、契約法院、騎士團、學院與商業城邦並存，龍族遺產可能成為政治資產。",
        culture: "寶物記憶、誓言、熱源節、飛行儀式與祖龍故事構成文化，不同支系可互相爭論正統。",
        language: "低頻共鳴、氣息、符文與通用語可並存；長記憶詞彙可能讓翻譯和時間觀變得困難。",
        technology: "熔煉、飛行器、耐熱材料、符文與城市能源系統支撐生活，資源和安全成本很高。",
        relations: "與人類、矮人、精靈及真正龍族的關係可圍繞血統、契約、資源與自治權發展。",
        prompt: "可從龍血身份是否等於權利、個人與祖先契約、能力代價及社群自治切入。"
    )]) [0]

    static let merfolk = make(.fictional, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000105")!, title: "海族",
        referenceCase: "原創海洋與沿岸混居族群", referencePeriod: "架空世界的海陸交流時代",
        summary: "適應海洋、河口與沿岸生活的架空族群；可包含不同水域支系與與陸地混居社群。",
        origin: "可源於海洋演化、沉沒文明、潮汐神話或與陸地族群的古代分化。",
        body: "鰓、鱗、蹼、發光器官或可變肢體可有多種組合，身體設計需連結環境需求。",
        lifecycle: "出生、變態、換鱗、潮汐成年或群體照護都可構成生命週期，水陸支系不必相同。",
        habitat: "珊瑚城、深海、河口、冰海與沿岸港口各有不同壓力，鹽度、光照與水壓是限制。",
        abilities: "游泳、回聲感知、潛水與潮汐判讀可成為優勢；離水時間、污染與海況是限制。",
        continuity: "卵群、家庭、潮汐社群、收養或船隊契約都可形成成員資格，親族不必只按血緣。",
        society: "礁群議會、船隊、港口商會、深海祭司與沿岸混居區並存，海流和航線影響權力。",
        culture: "潮汐節、歌唱、貝殼工藝、祖先航線與海葬構成文化，不同水域有不同禁忌。",
        language: "水下聲波、閃光、色彩、手勢與陸地語言可能分工，跨介質翻譯需要媒介。",
        technology: "潮汐能源、珊瑚建築、船舶、養殖、潛水工具與防腐材料支撐日常。",
        relations: "與陸地城市、海怪、商船和其他海族的關係可圍繞海域、污染、航線與通行權展開。",
        prompt: "可從海陸法律、污染責任、跨介質溝通與離水者身份切入。"
    )]) [0]

    static let undead = make(.fictional, [Seed(
        id: UUID(uuidString: "C0A3D7E1-3C10-4F01-9000-000000000106")!, title: "亡靈族",
        referenceCase: "原創記憶與死後身份社會", referencePeriod: "架空世界的死生秩序變動期",
        summary: "以死後延續、記憶保存或人工靈魂形成為基礎的架空族群；不預設邪惡或失去人格。",
        origin: "可由儀式、疾病、魔法、科技、集體記憶或自願轉化形成，不同群體對死亡有不同理解。",
        body: "骨骼、半透明、木乃伊化、機械載體或仍具生前外貌都可存在；身體狀態影響感官與需求。",
        lifecycle: "死亡、甦醒、記憶重組、軀體更換或靈魂分裂可構成生命週期，時間感可能與生者不同。",
        habitat: "墓城、地下檔案館、寒地、活人城市或移動容器都可居住，能量、記憶與安全是限制。",
        abilities: "耐病、記憶保存、夜視或不需呼吸可能存在；衰朽、記憶缺失、陽光與社會排斥是代價。",
        continuity: "靈魂認可、記憶繼承、收容院、轉化契約或共同墓籍都可形成成員資格，血緣不再唯一。",
        society: "墓城議會、記憶保管者、轉化工坊、活人外交與流亡群體並存，誰能定義死亡是核心權力。",
        culture: "送葬、追憶、姓名保存、身體修復與與生者互訪構成文化，禁忌可因年代而改變。",
        language: "記憶回聲、死者文字、鐘聲、符號或生前語言可能並用；身份與語言遺忘會互相影響。",
        technology: "保存術、容器、靈魂工藝、地下城市與記憶檔案支撐日常，維護成本和材料來源有限。",
        relations: "與生者、祭司、醫師、家族和其他亡靈的關係可圍繞安葬權、身份證明、資源與恐懼形成。",
        prompt: "可從死亡是否終點、記憶是否等於本人、活人法律與亡靈自治切入。"
    )]) [0]
}

struct PeoplePresetCatalogView: View {
    let allowsSelection: Bool
    let selectedID: UUID?
    let onSelect: ((PeoplePreset?) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var displayedPresetID: UUID?

    init(allowsSelection: Bool = false, selectedID: UUID? = nil, onSelect: ((PeoplePreset?) -> Void)? = nil) {
        self.allowsSelection = allowsSelection
        self.selectedID = selectedID
        self.onSelect = onSelect
        _displayedPresetID = State(initialValue: selectedID ?? PeoplePreset.all.first?.id)
    }

    private var displayedPreset: PeoplePreset? {
        PeoplePreset.preset(id: displayedPresetID)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $displayedPresetID) {
                ForEach(PeoplePresetGroup.allCases) { group in
                    SwiftUI.Section(group.rawValue) {
                        ForEach(PeoplePreset.all.filter { $0.group == group }) { preset in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(preset.title).font(.headline)
                                Text(preset.summary).font(.caption).foregroundStyle(.secondary)
                            }
                            .tag(preset.id)
                        }
                    }
                }
            }
            .navigationTitle("族群／種族")
        } detail: {
            if let displayedPreset {
                PeoplePresetDetailView(preset: displayedPreset)
                    .safeAreaInset(edge: .bottom) {
                        if allowsSelection {
                            HStack {
                                Button(SailuneActionCopy.clearSelection) {
                                    onSelect?(nil)
                                    dismiss()
                                }
                                Spacer()
                                Button(SailuneActionCopy.selectPreset(displayedPreset.title)) {
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
                ContentUnavailableView("請選擇族群／種族", systemImage: SailuneSymbol.people.systemName)
            }
        }
        .frame(minWidth: 860, minHeight: 620)
        .toolbar {
            Button(SailuneActionCopy.close) { dismiss() }
        }
    }
}

struct PeoplePresetDetailView: View {
    let preset: PeoplePreset

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(preset.title).font(.title2.weight(.bold))
                    Text(preset.group.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("參考脈絡：\(preset.referenceCase)")
                        .font(.subheadline.weight(.semibold))
                    Text("參考範圍：\(preset.referencePeriod)")
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
            .frame(maxWidth: 780, alignment: .leading)
        }
        .navigationTitle(preset.title)
    }
}
