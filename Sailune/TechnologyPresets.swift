import SwiftUI

struct TechnologyPresetSection: Identifiable, Equatable {
    let title: String
    let content: String

    var id: String { title }
}

/// 技術階段預設以固定的歷史案例或小說類型作為參考骨架，內容本身維持原創且不保存作品資料。
struct TechnologyPreset: Identifiable, Equatable {
    let id: UUID
    let title: String
    let referenceCase: String
    let referencePeriod: String
    let summary: String
    let sections: [TechnologyPresetSection]

    static let realWorld: [TechnologyPreset] = [
        hunterGatherer,
        neolithicAgriculture,
        bronzeAge,
        ironAge,
        preindustrial,
        industrial,
        electrification,
        informationNetwork,
        intelligentTechnology
    ]

    static let fictional: [TechnologyPreset] = [
        steampunk,
        steelpunk,
        wasteland,
        spaceAge,
        cultivation
    ]

    static var all: [TechnologyPreset] { realWorld + fictional }

    static func preset(id: UUID?) -> TechnologyPreset? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    static func matching(_ term: WorldTerm) -> TechnologyPreset? {
        all.first { preset in
            term.name == preset.title
                && term.termCategory == WorldTermCategory.technology.rawValue
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
        term.termCategory = WorldTermCategory.technology.rawValue
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

    private static func section(_ title: String, _ content: String) -> TechnologyPresetSection {
        TechnologyPresetSection(title: title, content: content)
    }

    static let hunterGatherer = TechnologyPreset(
        id: UUID(uuidString: "31C2E4A7-4B50-4D18-9D70-000000000101")!,
        title: "狩獵採集時代",
        referenceCase: "晚期舊石器狩獵採集社會",
        referencePeriod: "約西元前 20,000～10,000 年",
        summary: "以石器、火、複合工具、季節遷徙與口述技術為核心的狩獵採集社會。",
        sections: [
            section("世界前提與技術階段", "人口以小型流動群體生活，技術重點是直接取得食物、保暖、避難與跨季節遷徙。"),
            section("核心能源／超自然基礎", "人力、火、木材、石材、骨角與纖維是主要自然條件；工具效率受材料、燃料與環境限制。"),
            section("生產、製造與維修能力", "打製與磨製石器、骨角工具、繩索、皮革與複合武器由群體內傳授，磨損後就地修補或重新製作。"),
            section("資訊、知識與技術傳承", "口述、示範、模仿、地景記憶與季節觀察保存知識；長者、獵人與工匠是重要傳承者。"),
            section("交通、通訊與行動範圍", "步行、簡易舟具與動物協助移動；道路與遠距通訊尚未制度化，行動依賴水源、獵場與季節。"),
            section("日常生活與常用器物", "火塘、皮革衣物、容器、石刃、投射工具與簡易住所構成日常；器物常有多重用途。"),
            section("組織、權力與階層", "親族、年齡、技能、狩獵貢獻與儀式角色影響分工；權力通常依賴聲望與協商。"),
            section("資源、經濟與交換", "食物、石材、木材、皮革與季節性獵物是核心資源；交換多透過互惠、婚姻與群體聯盟完成。"),
            section("地景、居住與基礎設施", "洞穴、臨時營地、水源、獵徑與火塘組成生活地景；聚落會隨資源與氣候週期變動。"),
            section("風險、限制與失效後果", "乾旱、寒冷、傷病、獵物減少與群體分裂可能立即威脅生存；技術失效通常需靠遷徙補救。"),
            section("故事衝突與世界影響", "資源共享、遷徙路線、群體邊界、照護責任與如何保存記憶構成主要社會衝突。"),
            section("類型專屬特色", "強調環境觀察、流動性、口述記憶與低材料成本，不把缺乏大型基礎設施等同於缺乏複雜知識。")
        ]
    )

    static let neolithicAgriculture = TechnologyPreset(
        id: UUID(uuidString: "31C2E4A7-4B50-4D18-9D70-000000000102")!,
        title: "農業新石器時代",
        referenceCase: "黎凡特新石器聚落",
        referencePeriod: "約西元前 9,000～7,000 年",
        summary: "以農耕、畜養、定居、儲藏與聚落分工為核心的新石器技術階段。",
        sections: [
            section("世界前提與技術階段", "人群開始穩定種植與畜養，定居聚落擴大，生產週期與土地管理成為社會核心。"),
            section("核心能源／超自然基礎", "人力、畜力、火、木材、石材與可耕土地是主要基礎；降雨、土壤與季節決定產量。"),
            section("生產、製造與維修能力", "磨製石器、陶器、籃筐、紡織、灌溉與穀物加工提高儲藏能力；工具由家庭與專業工匠維護。"),
            section("資訊、知識與技術傳承", "播種節律、植物選育、畜養、陶器工藝與聚落規範透過示範、儀式與口述傳承。"),
            section("交通、通訊與行動範圍", "步行、舟具與馴化動物連接鄰近聚落；定居提高區域交換密度，但也增加對單一土地的依賴。"),
            section("日常生活與常用器物", "穀物、陶罐、磨盤、織物、屋舍與儲藏坑成為日常；食物加工與家務勞動更固定化。"),
            section("組織、權力與階層", "土地、糧倉、灌溉與祭儀管理者逐漸取得影響力；家庭、鄰里與聚落首領共同分配工作。"),
            section("資源、經濟與交換", "種子、土地、水、牲畜、陶器與剩餘糧食是核心資源；交換範圍擴大但仍受季節與運輸限制。"),
            section("地景、居住與基礎設施", "泥磚屋、糧倉、圍牆、道路、井與公共儀式空間形成較固定的聚落地景。"),
            section("風險、限制與失效後果", "歉收、病蟲害、牲畜疾病、土壤耗竭與人口擁擠可能造成飢荒與遷徙。"),
            section("故事衝突與世界影響", "定居帶來合作、人口成長與專業分工，也帶來土地所有、勞動分配、疾病與社會不平等。"),
            section("類型專屬特色", "以生產食物與儲藏剩餘為技術轉折，呈現定居並非單純進步，而是新的依賴、治理與風險組合。")
        ]
    )

    static let bronzeAge = TechnologyPreset(
        id: UUID(uuidString: "31C2E4A7-4B50-4D18-9D70-000000000103")!,
        title: "青銅時代",
        referenceCase: "商代晚期青銅工業",
        referencePeriod: "約西元前 13～11 世紀",
        summary: "以青銅冶鑄、車戰、文字記錄、城市與專業工匠為核心的技術階段。",
        sections: [
            section("世界前提與技術階段", "城市、農業與宮廷權力依賴金屬工具、武器、車輛與長距離物資調度。"),
            section("核心能源／超自然基礎", "木炭、火、銅錫礦、黏土與人畜力構成基礎；礦源、燃料與冶煉經驗限制產量。"),
            section("生產、製造與維修能力", "模具鑄造、鍛造、陶器、紡織與木工形成專業分工；青銅器可重熔，工具由工匠與作坊維護。"),
            section("資訊、知識與技術傳承", "文字、銘文、曆法、度量衡、工藝規格與宮廷檔案保存知識，識字與專業集中於少數群體。"),
            section("交通、通訊與行動範圍", "車輛、河運、道路與驛傳擴大統治範圍；山地、季節與牲畜補給仍限制行動速度。"),
            section("日常生活與常用器物", "陶器、石器、青銅刀具、紡織品、糧倉與牲畜構成生活；高品質金屬器物常具有身分象徵。"),
            section("組織、權力與階層", "王權、宗族、軍事、祭祀與工匠機構分層運作；能控制礦產與鑄造者掌握政治資源。"),
            section("資源、經濟與交換", "銅、錫、木炭、糧食、牲畜與勞動力是核心；遠距貿易與貢賦維持城市及軍事體系。"),
            section("地景、居住與基礎設施", "城牆、宮殿、作坊、祭壇、墓葬、道路與糧倉形成集中式城市景觀。"),
            section("風險、限制與失效後果", "礦源中斷、旱災、戰爭、鑄造失敗與運輸斷裂會削弱軍事與糧食分配。"),
            section("故事衝突與世界影響", "金屬技術強化國家、戰爭與祭祀權威，也加劇貢賦、奴役、工匠控制與邊疆競爭。"),
            section("類型專屬特色", "呈現金屬、文字與城市治理互相強化的社會，但不同地區可同時使用石器、木器與青銅。")
        ]
    )

    static let ironAge = TechnologyPreset(
        id: UUID(uuidString: "31C2E4A7-4B50-4D18-9D70-000000000104")!,
        title: "鐵器時代",
        referenceCase: "漢代早期鐵器社會",
        referencePeriod: "約西元前 2～1 世紀",
        summary: "以鐵製工具、冶鐵、道路、水利與國家生產組織為核心的技術階段。",
        sections: [
            section("世界前提與技術階段", "鐵製農具、武器與日常工具逐步普及，國家能以更大規模組織農業、軍事與工程。"),
            section("核心能源／超自然基礎", "木炭、鐵礦、鼓風、窯爐、水力、人力與畜力是基礎；礦石品質與冶煉溫度影響成品。"),
            section("生產、製造與維修能力", "鑄鐵、鍛鐵、鋼化、農具製作、陶窯與水利工程擴大生產；地方作坊與國營工場並存。"),
            section("資訊、知識與技術傳承", "文字行政、法律、工程規範、曆法與工匠師承保存技術；國家檔案提高跨地區管理能力。"),
            section("交通、通訊與行動範圍", "道路、橋樑、運河、車馬與驛站連接更廣領土；行政命令能更快傳遞但仍受距離與季節影響。"),
            section("日常生活與常用器物", "鐵刀、犁、鍋、釘、馬具與木石建材進入日常；農業工具的耐用性提高勞動效率。"),
            section("組織、權力與階層", "官僚、軍隊、地主、工匠、農民與商人形成多層組織；鐵礦與鹽等資源可能由國家控制。"),
            section("資源、經濟與交換", "鐵礦、木炭、糧食、馬匹、鹽、土地與稅收是核心；市場交換和國家徵收並行。"),
            section("地景、居住與基礎設施", "城鎮、道路、灌溉、冶鐵場、軍營與屯田構成國家化地景；邊疆工程維持交通與防衛。"),
            section("風險、限制與失效後果", "森林耗竭、洪水、戰亂、疫病與徵收壓力可能削弱生產；冶鐵與水利失修會造成長期衰退。"),
            section("故事衝突與世界影響", "鐵器擴大農業與軍事能力，也使中央集權、邊疆征服、階級分化與勞動負擔更加明顯。"),
            section("類型專屬特色", "重點在鐵器與行政工程如何讓大型國家延伸至地方，而非宣稱所有地區同時完成鐵器化。")
        ]
    )

    static let preindustrial = TechnologyPreset(
        id: UUID(uuidString: "31C2E4A7-4B50-4D18-9D70-000000000105")!,
        title: "前工業時代",
        referenceCase: "明代江南手工業與商業網絡",
        referencePeriod: "約 1500～1650 年",
        summary: "以水力、手工工場、印刷、航海、商業與區域市場為核心的前工業技術階段。",
        sections: [
            section("世界前提與技術階段", "農業仍是人口基礎，但手工生產、商業資本、城市與跨區域市場已形成複雜網絡。"),
            section("核心能源／超自然基礎", "人力、畜力、水力、風力、木材與煤炭提供能源；季節、水位與燃料運輸限制產能。"),
            section("生產、製造與維修能力", "作坊、工匠聚落、標準化工序與家庭副業並存；紡織、陶瓷、造紙、冶金與造船各有專業鏈。"),
            section("資訊、知識與技術傳承", "印刷、書院、商業帳簿、行會規範與師徒制度擴大知識流通，但識字與專業仍不均等。"),
            section("交通、通訊與行動範圍", "帆船、運河、驛站、道路與商隊連接區域市場；長距離運輸受風向、治安與季節限制。"),
            section("日常生活與常用器物", "紙張、布匹、陶瓷、金屬工具、煤油燈、秤與帳簿進入日常；城鄉生活差異很大。"),
            section("組織、權力與階層", "官僚、地主、商人、行會、工匠與佃農共同構成秩序；市場權力與行政權力彼此協商。"),
            section("資源、經濟與交換", "土地、糧食、絲棉、鹽、金屬、航運與信用是核心；區域價格差與商業網絡創造財富。"),
            section("地景、居住與基礎設施", "運河、碼頭、城牆、作坊、商號、集市與鄉村灌溉構成密集的人文地景。"),
            section("風險、限制與失效後果", "旱澇、饑荒、火災、盜匪、疫病、戰爭與金融斷裂會迅速影響市場和城市供應。"),
            section("故事衝突與世界影響", "商業擴張與行政控制、工匠自主與勞動束縛、城市繁榮與鄉村負擔形成主要矛盾。"),
            section("類型專屬特色", "呈現高密度手工技術與成熟市場，不把沒有工廠理解為沒有複雜分工或全球交流。")
        ]
    )

    static let industrial = TechnologyPreset(
        id: UUID(uuidString: "31C2E4A7-4B50-4D18-9D70-000000000106")!,
        title: "工業時代",
        referenceCase: "英國第一次工業革命",
        referencePeriod: "約 1760～1850 年",
        summary: "以蒸汽機、工廠、機械化紡織、鐵路與城市化為核心的現實工業技術階段。",
        sections: [
            section("世界前提與技術階段", "機械化生產逐步取代部分手工流程，工廠、城市與全球貿易成為社會組織的重要支柱。"),
            section("核心能源／超自然基礎", "煤炭、蒸汽、鐵、木材與水力提供能源；鍋爐安全、燃料運輸與散熱限制設備。"),
            section("生產、製造與維修能力", "工廠、機床、機械化紡織、煉鐵與標準零件提高產量；維修技師與工廠制度逐漸專業化。"),
            section("資訊、知識與技術傳承", "印刷報刊、專利、工程學校、公司帳簿與電報前身擴大知識流通；技術被納入企業管理。"),
            section("交通、通訊與行動範圍", "鐵路、蒸汽船、運河與郵政縮短距離；煤站、港口與鐵路節點決定行動範圍。"),
            section("日常生活與常用器物", "工業布料、煤氣照明、鐵製工具、工廠鐘聲與城市供水改變生活節奏；居住環境差異擴大。"),
            section("組織、權力與階層", "工業資本家、工程師、工人、政府與工會逐漸形成現代勞動政治；時間紀律成為管理工具。"),
            section("資源、經濟與交換", "煤、鐵、棉花、工廠、港口與金融資本是核心；全球原料與市場把地方生產連入帝國網絡。"),
            section("地景、居住與基礎設施", "煙囪、工廠、鐵路、礦區、工人住宅與港口重塑城市和鄉村地景。"),
            section("風險、限制與失效後果", "工傷、污染、礦災、鍋爐事故、失業與供應中斷會把機械化的效率轉成社會危機。"),
            section("故事衝突與世界影響", "工業化提高生產力與交通，也帶來勞資衝突、階級政治、帝國擴張、都市貧困與環境傷害。"),
            section("類型專屬特色", "與蒸汽朋克區分：這是現實的工廠、能源與勞動轉型，並保留制度、階級與地區差異。")
        ]
    )

    static let electrification = TechnologyPreset(
        id: UUID(uuidString: "31C2E4A7-4B50-4D18-9D70-000000000107")!,
        title: "電氣化與大量生產時代",
        referenceCase: "美國第二次工業革命",
        referencePeriod: "約 1880～1930 年",
        summary: "以電力、鋼鐵、化工、流水線、電話與大眾生產為核心的現代工業階段。",
        sections: [
            section("世界前提與技術階段", "電力網、現代企業與大量生產擴大商品供應，城市人口與工業組織快速集中。"),
            section("核心能源／超自然基礎", "煤電、水電、石油、鋼鐵、化工與電動機構成基礎；電網穩定與燃料供應決定產能。"),
            section("生產、製造與維修能力", "流水線、標準規格、工業實驗室與大企業提高產量；維修、品質控制與零件供應成為專門職能。"),
            section("資訊、知識與技術傳承", "電話、廣播、報紙、標準化教育與企業研發加速資訊流通；專利和公司資料庫集中技術權力。"),
            section("交通、通訊與行動範圍", "汽車、電車、鐵路、飛機、電話與港口網絡擴大移動；石油與電力基礎設施成為戰略節點。"),
            section("日常生活與常用器物", "電燈、家電、收音機、汽車、罐頭與標準化商品進入城市生活，消費文化逐漸形成。"),
            section("組織、權力與階層", "企業管理、工會、國家官僚與大眾政黨擴大影響；工業勞動和消費者身分重新排列階層。"),
            section("資源、經濟與交換", "石油、煤、鋼、橡膠、電力、金融與大眾市場是核心；全球供應鏈更緊密也更脆弱。"),
            section("地景、居住與基礎設施", "電廠、工業區、摩天樓、郊區、道路、電車與電話線構成現代城市骨架。"),
            section("風險、限制與失效後果", "停電、工業污染、金融崩潰、戰爭動員、流水線事故與大規模失業可能波及整個社會。"),
            section("故事衝突與世界影響", "大量生產降低商品成本，也擴大消費控制、勞動異化、帝國競爭與大眾政治。"),
            section("類型專屬特色", "關鍵不是單項發明，而是電力、企業、交通、通信與大眾市場組成彼此依賴的系統。")
        ]
    )

    static let informationNetwork = TechnologyPreset(
        id: UUID(uuidString: "31C2E4A7-4B50-4D18-9D70-000000000108")!,
        title: "資訊與網路時代",
        referenceCase: "早期全球網際網路社會",
        referencePeriod: "約 1990～2010 年",
        summary: "以個人電腦、數位通訊、網路服務、軟體與全球供應鏈為核心的資訊技術階段。",
        sections: [
            section("世界前提與技術階段", "資料可被數位化、複製與跨國傳輸，企業、政府與個人活動逐步依賴資訊系統。"),
            section("核心能源／超自然基礎", "半導體、電力、伺服器、光纖、行動通訊與資料中心是基礎；頻寬、算力與供電仍有限。"),
            section("生產、製造與維修能力", "軟體開發、晶片製造、網路維運與自動化工廠形成跨國分工；版本管理與系統更新成為維修核心。"),
            section("資訊、知識與技術傳承", "搜尋引擎、電子郵件、數位檔案、開放社群與線上教育擴大知識流通，也產生版權與資訊可信度問題。"),
            section("交通、通訊與行動範圍", "手機、網路、衛星、航空與全球物流連接世界；數位通信加速，但實體運輸仍受距離和能源約束。"),
            section("日常生活與常用器物", "個人電腦、手機、數位相機、信用卡、電子遊戲與線上服務重塑工作、娛樂與社交。"),
            section("組織、權力與階層", "跨國平台、軟體公司、政府、媒體與網路社群爭奪資料、注意力與標準制定權。"),
            section("資源、經濟與交換", "資料、晶片、頻寬、專利、平台使用者與全球物流是核心；數位服務與實體供應鏈互相依賴。"),
            section("地景、居住與基礎設施", "資料中心、電信基地台、辦公園區、物流港、網咖與家庭網路組成新的生活地景。"),
            section("風險、限制與失效後果", "斷網、資安攻擊、資料遺失、隱私外洩、平台壟斷與供應鏈中斷會放大局部故障。"),
            section("故事衝突與世界影響", "資訊技術擴大連結與創作，也帶來監控、數位落差、假訊息、版權衝突與工作型態改變。"),
            section("類型專屬特色", "以資料、連線與平台依賴為核心；數位化提高速度，但不消除實體資源與地理政治。")
        ]
    )

    static let intelligentTechnology = TechnologyPreset(
        id: UUID(uuidString: "31C2E4A7-4B50-4D18-9D70-000000000109")!,
        title: "智慧科技時代",
        referenceCase: "21 世紀人工智慧與生物科技社會",
        referencePeriod: "約 2010 年至今",
        summary: "以雲端、行動裝置、機器學習、生物工程與自動化為核心的當代技術階段。",
        sections: [
            section("世界前提與技術階段", "大量社會活動由雲端平台、感測器、演算法與生物資料支撐，技術更新速度快於制度調整。"),
            section("核心能源／超自然基礎", "高效能晶片、資料中心、電力、雲端網路、基因資料與自動化設備是基礎；能源、資料與算力形成瓶頸。"),
            section("生產、製造與維修能力", "機器人、生成式軟體、智慧工廠、基因編輯與遠端維運提高自動化；模型、資料與硬體需要持續更新。"),
            section("資訊、知識與技術傳承", "即時資料、開放研究、模型訓練、線上協作與數位助理加速知識生產；可解釋性與資料來源成為新要求。"),
            section("交通、通訊與行動範圍", "5G、衛星、共享運輸、無人系統與智慧物流擴大即時連線；基礎設施差距仍造成地區落差。"),
            section("日常生活與常用器物", "智慧手機、穿戴裝置、語音助理、串流服務、遠距醫療與家用自動化融入日常。"),
            section("組織、權力與階層", "平台企業、政府、研究機構、資料持有者與具備專業技能的人重新分配決策權；規範落後於部署速度。"),
            section("資源、經濟與交換", "資料、算力、晶片、能源、專利、生物樣本與模型服務是核心；平台依賴與供應鏈集中帶來新的市場權力。"),
            section("地景、居住與基礎設施", "資料中心、智慧城市、無人倉、實驗室、遠距工作空間與高密度通訊網形成混合地景。"),
            section("風險、限制與失效後果", "偏誤模型、資安事故、生物風險、深度偽造、能源短缺與自動化失誤可能快速擴散。"),
            section("故事衝突與世界影響", "智慧科技提升醫療、生產與協作，也加劇監控、責任歸屬、工作轉型、資料權與公平性爭議。"),
            section("類型專屬特色", "這是仍在變動的當代階段；內容保留技術未定型、規範追趕與不同社會採用速度不一的特徵。")
        ]
    )

    static let steampunk = TechnologyPreset(
        id: UUID(uuidString: "31C2E4A7-4B50-4D18-9D70-000000000001")!,
        title: "蒸汽朋克",
        referenceCase: "《差分機》",
        referencePeriod: "小說內 1855 年架空英國",
        summary: "以蒸汽動力、機械計算與維多利亞工業社會為核心的架空技術階段。",
        sections: [
            section("世界前提與技術階段", "蒸汽工業沒有被電力與數位技術取代，而是持續成為城市、交通、軍事與資訊處理的主要基礎。"),
            section("核心能源／超自然基礎", "煤炭、蒸汽壓力、鍋爐與機械傳動構成核心；技術依然受燃料、散熱、材料疲勞與維修條件限制。"),
            section("生產、製造與維修能力", "工廠以鍛造、車床、齒輪、鉚接與標準化零件生產設備；高級機械需要專門技師、工場與長時間保養。"),
            section("資訊、知識與技術傳承", "紙本檔案、印刷、電報與機械計算並存；專利、學會、工匠行會與工業家族掌握技術傳承。"),
            section("交通、通訊與行動範圍", "鐵路、蒸汽船、飛行器與電報網縮短距離，但速度、航線與能源補給仍受地理與階級資源限制。"),
            section("日常生活與常用器物", "城市生活充滿管線、鍋爐、機械鐘、工業照明與自動裝置；家庭設備的普及程度取決於地區與收入。"),
            section("組織、權力與階層", "工業資本家、工程師、政府與工人階級掌握不同資源；機械效率常被用來合理化勞動控制與都市階層。"),
            section("資源、經濟與交換", "煤礦、鋼材、工廠、鐵路節點與專利是核心資產；能源價格與工業產能直接影響城市安全與國力。"),
            section("地景、居住與基礎設施", "煙囪、工廠、車站、地下管道、橋樑與高密度住宅構成都市景觀；污染與噪音是繁榮的長期代價。"),
            section("風險、限制與失效後果", "鍋爐爆炸、燃料短缺、機械故障、工業污染與資訊壟斷可能使整座城市停擺，技術並不等於安全。"),
            section("故事衝突與世界影響", "工業化帶來移動、教育與生產力，也加劇勞資衝突、帝國競爭、環境傷害與誰能控制知識的問題。"),
            section("類型專屬特色", "以早到一個世紀的計算與蒸汽工業為特色，讓機械技術同時成為社會進步的希望與階級控制的工具。")
        ]
    )

    static let steelpunk = TechnologyPreset(
        id: UUID(uuidString: "31C2E4A7-4B50-4D18-9D70-000000000002")!,
        title: "鋼鐵朋克",
        referenceCase: "《移動城市》",
        referencePeriod: "小說第一部的移動城市文明",
        summary: "以大型鋼鐵機械、重工業遺產、移動聚落與資源競爭為核心的虛構技術類型。",
        sections: [
            section("世界前提與技術階段", "城市、工廠與武裝平台都被建造成可移動的鋼鐵系統；文明以重工業遺產維持自身，並在荒蕪大地上競逐位置。"),
            section("核心能源／超自然基礎", "燃料、電力、引擎與高強度金屬是主要基礎；巨型機械需要持續供能、散熱、潤滑與替換零件。"),
            section("生產、製造與維修能力", "大型鑄造廠、拆解場、維修甲板與工業工會維持機械；小型社群只能回收零件並以不完整規格拼裝。"),
            section("資訊、知識與技術傳承", "工程圖、維修手冊、導航資料與口傳技術同樣重要；掌握舊世界資料的人能左右整座聚落的生存。"),
            section("交通、通訊與行動範圍", "城市履帶、輪組、軌道平台與裝甲車隊構成交通；移動速度受地形、燃料、機械磨損與敵對聚落限制。"),
            section("日常生活與常用器物", "生活空間被壓縮在艙室、維修層與工業管線之間；水、空氣、照明、工具與防護裝備都是按配給管理的日常物資。"),
            section("組織、權力與階層", "駕駛、工程、武裝、資源管理與城市議會形成權力核心；能控制引擎與武器者往往支配不能離開平台的居民。"),
            section("資源、經濟與交換", "燃料、金屬、乾淨水、電池、彈藥與可用零件是主要貨幣；拆解、掠奪、護航與交換構成經濟。"),
            section("地景、居住與基礎設施", "荒原、廢墟、礦坑、工業遺跡與移動城市構成地景；固定聚落與移動聚落對土地和資源有不同依賴。"),
            section("風險、限制與失效後果", "履帶斷裂、能源耗盡、裝甲破損、零件絕版與生態危害可能使整個城市成為無法救援的孤島。"),
            section("故事衝突與世界影響", "重工業讓人類重新掌握移動與防衛，也使資源競爭、城市吞併、階級壓迫與環境代價變得制度化。"),
            section("類型專屬特色", "鋼鐵朋克在本產品中指重型機械文明與荒原資源競逐的類型，不是現實技術史，也不要求所有作品採用相同機械原理。")
        ]
    )

    static let wasteland = TechnologyPreset(
        id: UUID(uuidString: "31C2E4A7-4B50-4D18-9D70-000000000003")!,
        title: "廢土",
        referenceCase: "《長路》",
        referencePeriod: "小說內的災後美國",
        summary: "以文明崩潰、資源短缺、基礎設施殘骸與社群重建為核心的災後世界類型。",
        sections: [
            section("世界前提與技術階段", "既有文明已崩潰，倖存者只能從殘骸中尋找可用技術；世界的關鍵不是發明速度，而是能否維持基本生活。"),
            section("核心能源／超自然基礎", "燃料、可飲用水、食物、火源與可重複使用的工具是核心；高科技設備多已失去供應鏈與維修能力。"),
            section("生產、製造與維修能力", "生產退回小規模修補、拆解、種植、狩獵與手工製作；少數仍能運作的設備被視為珍貴遺產。"),
            section("資訊、知識與技術傳承", "地圖、書籍、口述記憶、技能示範與警示標記保存前文明知識；失去教育網絡後，記憶本身成為生存資源。"),
            section("交通、通訊與行動範圍", "步行、簡易車輛與馱運取代大規模交通；通訊依賴短距離接觸、信使與可見標記，遠方資訊極不可靠。"),
            section("日常生活與常用器物", "容器、保暖衣物、過濾器、刀具、火種與簡單醫療用品直接決定生存；每件可重用物品都可能有多重用途。"),
            section("組織、權力與階層", "小型家庭、流動群體、封閉聚落與掠奪團體各自建立規則；食物、武器、醫療和庇護決定誰能制定規則。"),
            section("資源、經濟與交換", "乾淨水、罐裝食物、藥品、燃料、種子與工具以物易物；貨幣與大規模市場失去作用，信任與武力成為交換條件。"),
            section("地景、居住與基礎設施", "燒毀城市、荒蕪道路、廢棄房屋、檢查站與臨時營地構成地景；安全居所通常只能短期使用。"),
            section("風險、限制與失效後果", "寒冷、飢餓、疾病、污染、暴力與孤立同時存在；任何一項關鍵物資中斷都可能讓群體迅速失去生存能力。"),
            section("故事衝突與世界影響", "廢土讓故事集中處理生存與倫理：保護他人、分享資源、保存文明與避免重演舊世界暴力之間持續衝突。"),
            section("類型專屬特色", "以災後美國的灰燼、長途遷徙與人性選擇為參考，強調技術退化後仍可由記憶、照護與道德維繫文明。")
        ]
    )

    static let spaceAge = TechnologyPreset(
        id: UUID(uuidString: "31C2E4A7-4B50-4D18-9D70-000000000004")!,
        title: "太空時代",
        referenceCase: "《蒼穹浩瀚：利維坦覺醒》",
        referencePeriod: "小說第一部的太陽系殖民時期",
        summary: "以地球、火星與小行星帶的人類殖民、太空航運與政治競爭為核心的近未來技術階段。",
        sections: [
            section("世界前提與技術階段", "人類已能長期生活於地球之外，但仍受限於太陽系尺度、航行時間、重力環境與有限資源。"),
            section("核心能源／超自然基礎", "火箭推進、反應爐、生命維持、人工重力與通訊系統構成核心；技術不取消距離與物理風險。"),
            section("生產、製造與維修能力", "太空船塢、軌道工廠、行星基地與小行星採礦形成分散供應鏈；維修能力決定船員與殖民地的自主性。"),
            section("資訊、知識與技術傳承", "高速資料網、導航紀錄、醫療資料與工程標準支撐跨行星社會；資料權限與通訊延遲仍影響政治決策。"),
            section("交通、通訊與行動範圍", "飛船、貨運航線與太空站連接地球、火星和小行星帶；加速、減速、燃料與航道使每次移動都具成本。"),
            section("日常生活與常用器物", "居住艙、循環水、合成食物、低重力醫療、太空服與維修工具構成日常；身體會因不同重力環境而產生差異。"),
            section("組織、權力與階層", "地球政府、火星政權、企業、船員與小行星帶社群掌握不同權力；航線、空氣與水的控制會轉化為政治權力。"),
            section("資源、經濟與交換", "冰、水、礦產、燃料、稀有材料與運輸艙位是核心資源；殖民地依賴貿易，又因依賴關係要求自治。"),
            section("地景、居住與基礎設施", "軌道站、船艙、火星穹頂、小行星居住地與行星港口構成多重地景；每個空間都必須管理氣壓與能源。"),
            section("風險、限制與失效後果", "真空、輻射、重力差、航道事故、生命維持故障與通訊延遲會把局部問題迅速放大成群體危機。"),
            section("故事衝突與世界影響", "太空殖民擴大人類活動範圍，也複製殖民、階級、資源分配與政治代表問題，讓太陽系成為新的權力邊界。"),
            section("類型專屬特色", "以太陽系殖民的工程限制與政治現實為核心，讓太空不是抽象背景，而是每個人物每天都必須維護的生存環境。")
        ]
    )

    static let cultivation = TechnologyPreset(
        id: UUID(uuidString: "31C2E4A7-4B50-4D18-9D70-000000000005")!,
        title: "修仙",
        referenceCase: "《凡人修仙傳》",
        referencePeriod: "小說前期凡人踏入修行界時",
        summary: "以靈氣、功法、丹藥、法器、宗門與境界累積為核心的虛構修行技術階段。",
        sections: [
            section("世界前提與技術階段", "世界存在可被修煉、轉化與傳承的靈氣；個人、宗門與國家以修行能力重新排列資源和安全。"),
            section("核心能源／超自然基礎", "靈氣、靈石、靈脈與天材地寶是核心；修行者透過功法、心法與境界將外在能量轉化為自身能力。"),
            section("生產、製造與維修能力", "煉丹、煉器、制符、布陣與靈植形成專業分工；高階材料、師承與火候決定成品品質。"),
            section("資訊、知識與技術傳承", "功法、玉簡、師徒、宗門藏經閣與秘境保存知識；錯誤功法、殘卷與資訊壟斷會直接造成修行風險。"),
            section("交通、通訊與行動範圍", "御器、遁法、傳音符、傳送陣與靈獸拓展行動範圍；修為差距、靈力消耗與地脈條件限制使用。"),
            section("日常生活與常用器物", "儲物器、護身符、療傷丹、照明法器與低階陣法進入日常；凡人與修士的生活需求仍有巨大落差。"),
            section("組織、權力與階層", "宗門、家族、散修聯盟、修真坊市與地方政權共同運作；境界、師承、資源與名望形成多層階級。"),
            section("資源、經濟與交換", "靈石、丹藥、功法、法器、洞府與靈脈是核心資源；交易、任務、拍賣、秘境探索與宗門供給維持經濟。"),
            section("地景、居住與基礎設施", "宗門山門、坊市、洞府、靈脈、禁地與秘境構成地景；地脈和陣法使空間本身成為可爭奪的技術資產。"),
            section("風險、限制與失效後果", "走火入魔、境界瓶頸、因果反噬、資源枯竭、渡劫失敗與高階修士衝突可能摧毀個人或宗門。"),
            section("故事衝突與世界影響", "修行帶來超越凡俗的可能，也把壽命、資源、師徒義務、宗門政治與凡人權利轉化為長期衝突。"),
            section("類型專屬特色", "以凡人從低階資源與不確定師承中逐步建立修行能力為參考，強調累積、風險、境界與資源交換，而非單純天賦。")
        ]
    )
}

struct TechnologyPresetCatalogView: View {
    let allowsSelection: Bool
    let selectedID: UUID?
    let onSelect: ((TechnologyPreset?) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var displayedPresetID: UUID?

    init(allowsSelection: Bool = false, selectedID: UUID? = nil, onSelect: ((TechnologyPreset?) -> Void)? = nil) {
        self.allowsSelection = allowsSelection
        self.selectedID = selectedID
        self.onSelect = onSelect
        _displayedPresetID = State(initialValue: selectedID ?? TechnologyPreset.all.first?.id)
    }

    private var displayedPreset: TechnologyPreset? {
        TechnologyPreset.preset(id: displayedPresetID)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $displayedPresetID) {
                SwiftUI.Section("現實歷史階段") {
                    ForEach(TechnologyPreset.realWorld) { preset in
                        TechnologyPresetRow(preset: preset)
                    }
                }
                SwiftUI.Section("虛構技術階段") {
                    ForEach(TechnologyPreset.fictional) { preset in
                        TechnologyPresetRow(preset: preset)
                    }
                }
            }
            .navigationTitle("技術階段")
        } detail: {
            if let displayedPreset {
                TechnologyPresetDetailView(preset: displayedPreset)
                    .safeAreaInset(edge: .bottom) {
                        if allowsSelection {
                            HStack {
                                Button("不選擇") {
                                    onSelect?(nil)
                                    dismiss()
                                }
                                Spacer()
                                Button("選擇\(displayedPreset.title)") {
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
                ContentUnavailableView("請選擇技術階段", systemImage: "gearshape.2")
            }
        }
        .frame(minWidth: 760, minHeight: 620)
        .toolbar {
            Button("關閉") { dismiss() }
        }
    }
}

private struct TechnologyPresetRow: View {
    let preset: TechnologyPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(preset.title).font(.headline)
            Text(preset.referenceCase).font(.caption).foregroundStyle(.secondary)
        }
        .tag(preset.id)
    }
}

struct TechnologyPresetDetailView: View {
    let preset: TechnologyPreset

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(preset.title).font(.title2.weight(.bold))
                    Text(TechnologyPreset.realWorld.contains(preset) ? "現實歷史階段" : "虛構技術階段")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("參考作品：\(preset.referenceCase)")
                        .font(.subheadline.weight(.semibold))
                    Text("參考時間：\(preset.referencePeriod)")
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
