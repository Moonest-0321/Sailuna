import SwiftUI

struct BeliefPresetSection: Identifiable, Equatable {
    let title: String
    let content: String

    var id: String { title }
}

/// 信仰預設採單一歷史案例，避免把不同時期、教派或社群的安排混成同一份固定內容。
struct BeliefPreset: Identifiable, Equatable {
    let id: UUID
    let title: String
    let referenceCase: String
    let referencePeriod: String
    let summary: String
    let sections: [BeliefPresetSection]

    static let all: [BeliefPreset] = [
        christianity,
        judaism,
        islam,
        taoism,
        buddhism,
        zoroastrianism,
        science,
        highControlGroup,
        apocalypticNewReligiousMovement
    ]

    static func preset(id: UUID?) -> BeliefPreset? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    static func matching(_ term: WorldTerm) -> BeliefPreset? {
        all.first { preset in
            term.name == preset.title
                && term.termCategory == WorldTermCategory.belief.rawValue
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
        term.termCategory = WorldTermCategory.belief.rawValue
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

    private static func section(_ title: String, _ content: String) -> BeliefPresetSection {
        BeliefPresetSection(title: title, content: content)
    }

    static let christianity = BeliefPreset(
        id: UUID(uuidString: "79A0D3E1-9C94-4B0B-8E61-000000000001")!,
        title: "基督教",
        referenceCase: "羅馬天主教會",
        referencePeriod: "1992 年《天主教教理》頒布時",
        summary: "以三位一體的上帝、耶穌基督的救恩與教會聖禮生活為核心的羅馬天主教信仰。",
        sections: [
            section("起源／核心信念", "信仰承接以色列的啟示傳統，宣認唯一上帝為聖父、聖子、聖神三位一體；耶穌基督降生、受難、復活，使人得以蒙恩得救。"),
            section("權威來源與經典", "《聖經》、聖傳與教會訓導共同構成信仰傳承；教宗與主教團在其職務內解釋信仰與道德教導。"),
            section("神聖對象或終極實在", "唯一創造者上帝；耶穌基督被宣認為真天主亦真人，聖神使教會與信徒在恩寵中生活。"),
            section("組織與領導", "教宗為羅馬主教及普世教會可見合一的中心；主教、司鐸、執事與修會在地方教會及堂區牧養信徒。"),
            section("儀式與實踐", "彌撒是共同敬拜的中心，七件聖事標記並分施恩寵；祈禱、讀經、告解、慈善與守齋構成日常靈修。"),
            section("倫理與生活規範", "以愛主愛人、十誡、福音與良心培育為倫理基礎，強調人的尊嚴、悔改、寬恕、家庭與服務他人。"),
            section("成員身分與加入", "透過洗禮加入教會；慕道、堅振與聖體禮深化完全的教會生活，信徒可依不同聖召成家、領受聖職或入修會。"),
            section("節期與空間", "禮儀年以將臨期、聖誕期、四旬期、復活期與常年期組成；主教座堂、堂區教堂與聖所是主要禮儀空間。"),
            section("異端／解釋差異", "此預設只呈現羅馬天主教會的 1992 年教理內容；其他基督宗派及天主教內不同神學取向不併入此固定案例。"),
            section("與世俗權力關係", "教會主張宗教自由與教會在其使命上的自主，同時鼓勵信徒以良心參與公共生活，不把福音使命等同任何單一政權。"),
            section("世界影響", "堂區、學校、醫療、慈善、婚喪禮儀、節期與藝術共同塑造社群生活，也可能引出教義、權威與世俗化之間的衝突。"),
            section("案例特色", "此案例以全球層級的教理、聖事與主教制為骨架，強調信仰所信、所慶祝、所實踐與所祈禱的整體秩序。")
        ]
    )

    static let judaism = BeliefPreset(
        id: UUID(uuidString: "79A0D3E1-9C94-4B0B-8E61-000000000002")!,
        title: "猶太教",
        referenceCase: "邁蒙尼德式拉比猶太教",
        referencePeriod: "約 1170～1180 年《密西尼托拉》完成期",
        summary: "以獨一上帝、妥拉誡命與拉比法傳統組織日常生活的中世紀拉比猶太教。",
        sections: [
            section("起源／核心信念", "信仰以以色列與上帝所立之約、妥拉啟示與遵守誡命為中心，承認獨一、無形且創造萬物的上帝。"),
            section("權威來源與經典", "成文妥拉、希伯來聖經與口傳律法構成核心；《密西尼托拉》將哈拉卡系統化，作為學習與實踐的法律指南。"),
            section("神聖對象或終極實在", "唯一的上帝是創造者、立法者與審判者；敬拜不以人或物為神，強調對上帝之獨一性的承認。"),
            section("組織與領導", "沒有單一普世教會階層；拉比、法學者、社群長老與會堂領袖在各地社群負責教導、裁斷與公共事務。"),
            section("儀式與實踐", "每日祈禱、安息日、會堂聚會、飲食規範、割禮與節期禮儀使誡命落實到家庭與社群日常。"),
            section("倫理與生活規範", "哈拉卡涵蓋敬拜、飲食、安息、財產、家庭與公共責任；慈善、公義、學習與守約是重要倫理實踐。"),
            section("成員身分與加入", "身分通常依出生或依宗教法完成歸信程序取得；家庭、教育與社群共同維繫誡命生活與集體記憶。"),
            section("節期與空間", "安息日是每週聖時；逾越節、贖罪日、住棚節等節期重述共同歷史。會堂、家庭與學習場所都是重要實踐空間。"),
            section("異端／解釋差異", "此案例以中世紀拉比法律傳統為準，不代表現代正統、保守、改革或其他猶太社群的所有做法。"),
            section("與世俗權力關係", "散居社群多在非猶太統治者之下，以社群自治、法學裁斷及與當局協商維持宗教生活，政治權力不是本案例的中心。"),
            section("世界影響", "律法將時間、飲食、家庭、商業與教育組織為具辨識度的社群生活，並可能在同化、限制與離散處境中形成張力。"),
            section("案例特色", "以《密西尼托拉》的系統化法典為骨架，凸顯信仰、律法、學習與日常實踐彼此不可分離。")
        ]
    )

    static let islam = BeliefPreset(
        id: UUID(uuidString: "79A0D3E1-9C94-4B0B-8E61-000000000003")!,
        title: "伊斯蘭教",
        referenceCase: "鄂圖曼帝國遜尼派哈乃斐傳統",
        referencePeriod: "蘇萊曼一世時期（1520～1566）",
        summary: "以《古蘭經》、遜奈與哈乃斐法學傳統組織敬拜、倫理與社群生活的鄂圖曼遜尼派伊斯蘭教。",
        sections: [
            section("起源／核心信念", "宣認真主獨一、穆罕默德為真主使者，並承認天使、經典、眾先知、末日與前定；信仰與順服真主構成核心。"),
            section("權威來源與經典", "《古蘭經》為最高經典，聖訓與先知遜奈提供實踐依據；哈乃斐法學以經文、聖訓、類比與法學共識推演規範。"),
            section("神聖對象或終極實在", "真主是唯一、全能、仁慈的創造者與審判者；不以任何人、物或形象與真主並列。"),
            section("組織與領導", "清真寺由伊瑪目帶領禮拜，烏里瑪負責宗教法律與教學；鄂圖曼的謝赫伊斯蘭在國家宗教法學體系中具重要地位。"),
            section("儀式與實踐", "五功包括念證、禮拜、天課、齋戒與朝覲；每日禮拜、聚禮、齋月與施捨將信仰落實於個人與社群。"),
            section("倫理與生活規範", "沙里亞規範敬拜、家庭、商業、慈善與公共秩序；強調公義、憐憫、誠信、節制與對弱勢者的責任。"),
            section("成員身分與加入", "誦念清真言並接受其意義即進入伊斯蘭社群；出生家庭、清真寺教育與法律身分共同維繫成員生活。"),
            section("節期與空間", "齋月、開齋節、宰牲節與週五聚禮是重要時間；清真寺、學校、慈善基金與朝覲路線構成宗教生活網絡。"),
            section("異端／解釋差異", "此案例只採鄂圖曼官方支持的遜尼派哈乃斐傳統；什葉派、其他遜尼法學派、蘇菲教團及現代各種詮釋不併入此固定內容。"),
            section("與世俗權力關係", "蘇丹以政治統治與保護宗教秩序相結合，法官、學校與慈善基金受國家架構支持；宗教法與蘇丹法並行。"),
            section("世界影響", "禮拜時間、齋戒、飲食、婚姻、慈善與法律語彙塑造城市及家庭生活，也會影響社群身分、法學權威與國家治理。"),
            section("案例特色", "以早期近代鄂圖曼的哈乃斐法學與國家支持的宗教機構為骨架，不把整個伊斯蘭世界的多樣傳統收斂成單一樣貌。")
        ]
    )

    static let taoism = BeliefPreset(
        id: UUID(uuidString: "79A0D3E1-9C94-4B0B-8E61-000000000004")!,
        title: "道教",
        referenceCase: "明代正一道",
        referencePeriod: "1445 年《正統道藏》成書後",
        summary: "以道、神祇譜系、符籙齋醮與道法傳承組織地方宗教生活的明代正一道。",
        sections: [
            section("起源／核心信念", "以道為宇宙根源與秩序，承接天師道、經典、神譜與修持傳統；透過齋醮、符籙與戒律追求與道相應、保生度人。"),
            section("權威來源與經典", "《道藏》彙集經、戒、法、科儀與註解；天師傳統的法籙、師承與授受確立法職與儀式權威。"),
            section("神聖對象或終極實在", "道為終極根源；三清、天庭神祇、星辰、祖師與地方神明構成多層神聖秩序，並以科儀與人間社群相連。"),
            section("組織與領導", "正一道重視授籙道士、法師與師徒傳承；地方宮觀、壇場與家族／社區的醮會需求共同構成實際組織。"),
            section("儀式與實踐", "齋醮、設壇、誦經、步罡、符籙、祈福、禳災與超度等科儀，用以調和人神、驅邪解厄與安定地方。"),
            section("倫理與生活規範", "戒律、善書、因果報應、敬天尊祖與濟世利人引導行為；修持可包含齋戒、誦經、存思與遵守法職規範。"),
            section("成員身分與加入", "一般信眾可參與廟會、祈禳與還願；道士以師承、受籙或受戒取得儀式職分，並非所有信眾都必須出家。"),
            section("節期與空間", "神誕、節令、地方廟會與設醮日是重要時間；宮觀、廟宇、壇場、家宅及地方社區皆可成為儀式空間。"),
            section("異端／解釋差異", "此案例限定明代正一道，不將全真道、民間信仰、儒佛融合實踐或後世不同道派視為同一固定制度。"),
            section("與世俗權力關係", "明代國家對宗教活動有登記、敕賜與管理，同時地方官與士紳常在祈禳、祭祀與地方秩序上與道士互動。"),
            section("世界影響", "地方節期、神明網絡、驅邪治病、祖先與社群互助使道教嵌入日常生活，也可能引出正統性、法術與官方管理的衝突。"),
            section("案例特色", "以《正統道藏》完成後的正一道法籙與地方齋醮網絡為骨架，呈現經典、師承與社區科儀的結合。")
        ]
    )

    static let buddhism = BeliefPreset(
        id: UUID(uuidString: "79A0D3E1-9C94-4B0B-8E61-000000000005")!,
        title: "佛教",
        referenceCase: "暹羅上座部佛教僧團",
        referencePeriod: "1902 年《僧伽法》施行時",
        summary: "以四聖諦、八正道、三寶與戒律為核心，並由國家化僧團階層組織的暹羅上座部佛教。",
        sections: [
            section("起源／核心信念", "以佛陀覺悟所揭示的四聖諦、緣起、無常、無我與解脫為核心；修行者依八正道止息苦與其根源。"),
            section("權威來源與經典", "巴利三藏、註釋與戒律是主要權威；僧團以律藏規範出家生活，教義由長老、學院與講經傳承。"),
            section("神聖對象或終極實在", "不以創世主神為信仰中心；佛、法、僧為三寶，涅槃是貪瞋癡止息與解脫的目標。"),
            section("組織與領導", "僧伽由比丘與沙彌組成；1902 年法律建立以最高僧王為頂點的全國僧團階層，並把地方寺院納入管理。"),
            section("儀式與實踐", "受戒、誦戒、禪修、布施、誦經、供養與功德迴向是重要實踐；在家眾以供僧、持戒與參與寺院生活累積善業。"),
            section("倫理與生活規範", "五戒引導在家眾避免殺生、偷盜、邪淫、妄語與酒醉；出家眾遵守更完整的戒律，重視慈悲、正念與不害。"),
            section("成員身分與加入", "在家眾以皈依三寶與受持戒律參與；男性可依規程出家或短期受戒，僧團身分由授戒與戒律生活確立。"),
            section("節期與空間", "衛塞節、雨安居、布薩日與供僧儀式組織宗教時間；寺院兼具修行、教育、葬儀與社群集會功能。"),
            section("異端／解釋差異", "此案例只呈現 1902 年暹羅的上座部僧團，不代表大乘、金剛乘、其他上座部地區或近代改革運動。"),
            section("與世俗權力關係", "僧伽法將僧團組織納入國家化的階層管理，王權保護佛教並透過中央僧團影響地方寺院秩序。"),
            section("世界影響", "寺院、布施、功德、教育、葬儀與節期把佛教嵌入村落生活；僧團中央化也可能改變地方傳統與宗教權威。"),
            section("案例特色", "以 1902 年僧伽法形成的全國僧團階層為骨架，將上座部戒律生活與近代國家管理同時呈現。")
        ]
    )

    static let zoroastrianism = BeliefPreset(
        id: UUID(uuidString: "79A0D3E1-9C94-4B0B-8E61-000000000006")!,
        title: "祆教",
        referenceCase: "薩珊波斯祆教",
        referencePeriod: "霍斯勞一世在位（531～579）",
        summary: "以阿胡拉・馬茲達、善惡抉擇、火廟祭儀與祭司傳統維繫的薩珊波斯祆教。",
        sections: [
            section("起源／核心信念", "信仰以祆教先知查拉圖斯特拉的啟示為根源，宣認阿胡拉・馬茲達為至善智慧之主；人須以善思、善言、善行對抗惡與虛妄。"),
            section("權威來源與經典", "《阿維斯陀》、禮儀傳承與祭司解釋構成權威；薩珊時期以中古波斯語宗教文獻與祭司學習整理教義與法規。"),
            section("神聖對象或終極實在", "阿胡拉・馬茲達是至高善神；善惡衝突具有宇宙性，火象徵光明、純淨與神聖秩序，而非被當作神本身。"),
            section("組織與領導", "祭司階層主持火廟與祭儀，並在王權支持下管理宗教事務；高階祭司與宮廷、地方社群形成互相支撐的權威網絡。"),
            section("儀式與實踐", "火廟敬拜、祈禱、淨化、祭禮與守護火焰是重要實踐；宗教生活重視避免污染土、水、火等被視為潔淨的要素。"),
            section("倫理與生活規範", "善思、善言、善行引導個人誠實、勤勞、守約與扶助善的秩序；淨與不淨的規範也影響疾病、死亡與日常處置。"),
            section("成員身分與加入", "社群多以家族與出生維繫，兒童經納沃特儀式穿戴聖衣與腰帶後承擔宗教義務；祭司職分則經專門訓練與傳承取得。"),
            section("節期與空間", "諾魯孜、新年與季節祭典標記神聖時間；火廟、家宅祭壇與淨化場所是信仰實踐的重要空間。"),
            section("異端／解釋差異", "此案例以六世紀薩珊國家支持的祆教為準，不代表早期伊朗諸傳統、後世帕西社群或現代祆教的所有做法。"),
            section("與世俗權力關係", "王權將祆教視為帝國秩序的重要支柱，祭司制度與行政、法律及社會階層密切相連，但宗教權威並非完全等同君主個人。"),
            section("世界影響", "淨化、節期、婚喪、家族義務與王權正當性共同塑造社會秩序，也可能使宗教少數與官方正統之間產生壓力。"),
            section("案例特色", "以霍斯勞一世時期的薩珊國家宗教為骨架，著重宇宙善惡、火廟禮儀、祭司權威與帝國秩序的交織。")
        ]
    )

    static let science = BeliefPreset(
        id: UUID(uuidString: "79A0D3E1-9C94-4B0B-8E61-000000000007")!,
        title: "科學",
        referenceCase: "英國皇家學會的自然哲學共同體",
        referencePeriod: "1660 年創立至 1687 年《原理》出版",
        summary: "以觀察、實驗、公開論證與可修正知識為共同寄託的十七世紀英國自然哲學社群。",
        sections: [
            section("起源／核心信念", "自然哲學家相信自然界可經由觀察、測量、實驗與數學推理加以理解；主張知識應能公開檢視並隨證據修正。"),
            section("權威來源與經典", "經驗、可重現的觀察、論證與公開記錄是主要依據；學會通信、會議記錄、實驗報告與《自然哲學的數學原理》是代表性文本。"),
            section("神聖對象或終極實在", "不適用：此預設不宣稱神聖對象或超自然終極實在；其核心寄託是自然秩序可被探究與知識可被修正。"),
            section("組織與領導", "皇家學會由會員聚會、秘書通信與實驗管理者協作；學術聲望來自參與、證據、論證與同儕檢視，而非宗教聖職。"),
            section("儀式與實踐", "不適用：不設宗教儀式。定期集會、展示實驗、記錄結果、互通書信與出版，是維繫共同知識的方法性實踐。"),
            section("倫理與生活規範", "重視誠實記錄、公開論證、承認不確定性與接受反駁；此案例的參與者仍受其時代階級與性別限制，並非普遍平等的社群。"),
            section("成員身分與加入", "會員由既有成員與王室特許的組織程序吸納；十七世紀參與者主要是具資源與教育背景的男性自然哲學家，不是普遍大眾組織。"),
            section("節期與空間", "不適用：沒有神聖節期。倫敦會議、通信網絡、實驗場所、藏書與印刷出版構成知識共同體的活動空間。"),
            section("異端／解釋差異", "此案例只指十七世紀皇家學會的自然哲學實踐，不等同今日所有科學學科、科學哲學、科學教育或把科學當作政治意識形態的用法。"),
            section("與世俗權力關係", "學會受王室特許而成立，成員與國家、商業及教育機構互動；其研究可服務航海、醫學、技術與國家利益，但不構成國教。"),
            section("世界影響", "觀察、實驗、出版與可重複檢驗的習慣改變人們理解自然與權威的方式，也可能與既有傳統、資源分配及技術權力發生張力。"),
            section("案例特色", "以皇家學會從 1660 年成立到 1687 年出版《原理》的共同體為骨架，明確把科學處理為相信可驗證、可修正知識的方法寄託，而非宗教。")
        ]
    )

    static let highControlGroup = BeliefPreset(
        id: UUID(uuidString: "79A0D3E1-9C94-4B0B-8E61-000000000008")!,
        title: "高控制團體",
        referenceCase: "人民聖殿教",
        referencePeriod: "1977～1978 年蓋亞那社群時期",
        summary: "以人民聖殿教在蓋亞那的封閉社群為案例，呈現領袖權威、資訊控制與成員依賴高度集中的團體。",
        sections: [
            section("起源／核心信念", "人民聖殿教以基督教語彙、種族平等與社會主義理想建立號召，後期將集體生存、外部威脅與領袖忠誠置於個人判斷之上。"),
            section("權威來源與經典", "領袖講道、錄音、內部指示與團體敘事成為實際權威；外部資訊被選擇性過濾，成員難以自由檢驗主張。"),
            section("神聖對象或終極實在", "團體以集體解放與受迫害社群的存續作為最高目標，並把領袖的個人判斷置於高度神聖化或不可質疑的位置。"),
            section("組織與領導", "權力集中於領袖與核心幹部；勞動、居住、育兒、資源與紀律由團體管理，成員彼此監督並依賴組織分配。"),
            section("儀式與實踐", "集會、公開表態、勞動、集體生活與忠誠測試強化歸屬；此處描述用於辨識高控制模式，不提供操作或模仿方法。"),
            section("倫理與生活規範", "個人需求被要求服從團體目標與領袖命令；質疑、離開或與外界接觸可被視為背叛，造成高度心理與社會壓力。"),
            section("成員身分與加入", "成員先由社會服務與理想訴求吸引，進入後逐步增加時間、財務與人際依賴；離開成本隨隔離與資源集中而升高。"),
            section("節期與空間", "聚會與勞動日程由團體安排；蓋亞那社群的居住、工作與社交空間高度重疊，削弱成員取得外部支持的可能。"),
            section("異端／解釋差異", "此預設只分析人民聖殿教後期的高控制模式，不把所有新興宗教、共同生活社群或強烈信仰者自動視為高控制團體。"),
            section("與世俗權力關係", "團體透過政治與公共關係尋求支持，同時將外部調查、批評與家屬關切詮釋為威脅，因而加深對外部世界的不信任。"),
            section("世界影響", "這類結構可讓故事呈現歸屬、照護與平等承諾如何被控制、隔離與權力集中扭曲；受害者、家屬與求助網絡是重要視角。"),
            section("案例特色", "以 1977～1978 年蓋亞那封閉社群為骨架，重點在識別高控制與隔離的風險，不將悲劇事件浪漫化或操作化。")
        ]
    )

    static let apocalypticNewReligiousMovement = BeliefPreset(
        id: UUID(uuidString: "79A0D3E1-9C94-4B0B-8E61-000000000009")!,
        title: "末世型新興宗教運動",
        referenceCase: "奧姆真理教",
        referencePeriod: "1989～1995 年日本活動時期",
        summary: "以奧姆真理教為案例，呈現末世預言、領袖權威、封閉修行與暴力化風險交織的新興宗教運動。",
        sections: [
            section("起源／核心信念", "團體混合佛教、瑜伽、印度教與末世論語彙，將世界危機、救贖與團體使命連結，並以領袖的特殊地位作為核心。"),
            section("權威來源與經典", "領袖著作、講話與內部課程被視為主要解釋來源；團體內的教義詮釋集中，外部批評容易被描繪為敵意或誤解。"),
            section("神聖對象或終極實在", "以末世危機中的解脫、淨化與救贖為終極敘事，並把領袖塑造成掌握特殊知識與修行道路的唯一權威。"),
            section("組織與領導", "領袖及核心幹部掌握教義、修行、財務與組織決策；住居型成員與一般信徒之間存在不同程度的投入與依賴。"),
            section("儀式與實踐", "冥想、瑜伽、講座、修行課程與集體生活被用來塑造成員身分；此處僅作歷史描述，不提供任何危害性方法或細節。"),
            section("倫理與生活規範", "團體要求服從教義與領袖，並將外界危機視為迫近；當目的被絕對化且內部制衡消失時，可能合理化傷害他人的行動。"),
            section("成員身分與加入", "成員可由課程、修行與末世敘事接觸團體；投入增加後，居住、勞動、財務與人際關係可能逐步被組織控制。"),
            section("節期與空間", "課程、修行中心與共同生活場所安排成員時間；末世預言使日常安排被置於迫切準備與團體任務之下。"),
            section("異端／解釋差異", "此預設限定奧姆真理教 1989～1995 年的歷史脈絡，不把所有末世論、瑜伽團體、佛教或新興宗教運動等同於暴力。"),
            section("與世俗權力關係", "團體曾試圖取得公共影響力，也與媒體、受害者、警方及司法體系衝突；外部監督失靈或延遲會放大封閉組織的風險。"),
            section("世界影響", "案例可用於描寫末世焦慮、魅力型權威與封閉社群如何改變家庭、城市與公共安全；故事應保留受害者與退出者的主體性。"),
            section("案例特色", "以 1989～1995 年日本活動期為骨架，聚焦末世論與高度集權如何走向傷害風險，不將暴力或控制描寫成神秘魅力。")
        ]
    )
}

struct BeliefPresetCatalogView: View {
    let allowsSelection: Bool
    let selectedID: UUID?
    let onSelect: ((BeliefPreset?) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var displayedPresetID: UUID?

    init(allowsSelection: Bool = false, selectedID: UUID? = nil, onSelect: ((BeliefPreset?) -> Void)? = nil) {
        self.allowsSelection = allowsSelection
        self.selectedID = selectedID
        self.onSelect = onSelect
        _displayedPresetID = State(initialValue: selectedID ?? BeliefPreset.all.first?.id)
    }

    private var displayedPreset: BeliefPreset? {
        BeliefPreset.preset(id: displayedPresetID)
    }

    var body: some View {
        NavigationSplitView {
            List(BeliefPreset.all, selection: $displayedPresetID) { preset in
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.title).font(.headline)
                    Text(preset.referenceCase).font(.caption).foregroundStyle(.secondary)
                }
                .tag(preset.id)
            }
            .navigationTitle("信仰")
        } detail: {
            if let displayedPreset {
                BeliefPresetDetailView(preset: displayedPreset)
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
                ContentUnavailableView("請選擇信仰", systemImage: SailuneSymbol.belief.systemName)
            }
        }
        .frame(minWidth: 760, minHeight: 620)
        .toolbar {
            Button(SailuneActionCopy.close) { dismiss() }
        }
    }
}

struct BeliefPresetDetailView: View {
    let preset: BeliefPreset

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(preset.title).font(.title2.weight(.bold))
                    Text("參考案例：\(preset.referenceCase)")
                        .font(.subheadline.weight(.semibold))
                    Text("參考年代：\(preset.referencePeriod)")
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
