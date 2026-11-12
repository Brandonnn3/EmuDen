import XCTest
@testable import EmulatorDomain

final class ArtworkTests: XCTestCase {
    let catalog = ArtworkCatalog(files: [
        "Mario Golf - World Tour (USA) (En,Fr,Es).png",
        "Mario Golf - World Tour (Europe) (En,Fr,De,Es,It,Nl,Pt,Ru).png",
        "Luigi's Mansion (USA).png",
        "Luigi's Mansion - Dark Moon (USA) (En,Fr,Es).png",
        "Luigi's Mansion 2 (Europe) (En,Fr,De,Es,It,Nl,Pt,Ru).png",
        "Legend of Zelda, The - Ocarina of Time 3D (USA) (En,Fr,Es).png",
        "Legend of Zelda, The - Ocarina of Time 3D (USA) (En,Fr,Es) (Rev 1).png",
        "Mario _ Luigi - Dream Team (USA).png",
        "Pokemon X (USA).png"
    ])
    func testExactGameAndRegionMatch() {
        XCTAssertEqual(catalog.match("Mario Golf - World Tour (USA) (En,Fr,Es)"), catalog.files[0])
        XCTAssertEqual(catalog.match("Mario Golf - World Tour (Europe)"), catalog.files[1])
    }
    func testSequelsAreNeverMatchedToAnotherGame() {
        XCTAssertEqual(catalog.match("Luigi's Mansion - Dark Moon (USA)"), catalog.files[3])
        XCTAssertEqual(catalog.match("Luigi's Mansion (USA)"), catalog.files[2])
        XCTAssertNil(catalog.match("Luigi's Mansion 3"))
        XCTAssertNil(catalog.match("Mario Golf"))
    }
    func testRevisionAndArticles() {
        XCTAssertEqual(catalog.match("The Legend of Zelda - Ocarina of Time 3D (USA) (Rev 1)"), catalog.files[6])
        XCTAssertEqual(catalog.match("The Legend of Zelda - Ocarina of Time 3D (USA)"), catalog.files[5])
    }
    func testAccentsPunctuationAndFileExtensions() {
        XCTAssertEqual(catalog.match("Mario & Luigi - Dream Team (USA).cci"), catalog.files[7])
        XCTAssertEqual(catalog.match("Pokémon X (USA)"), catalog.files[8])
        XCTAssertEqual(catalog.match("Luigi’s Mansion (USA)"), catalog.files[2])
    }
    func testUnknownNamesDoNotMatch() {
        XCTAssertNil(catalog.match("Unknown homebrew"))
        XCTAssertNil(catalog.match("こんにちは"))
    }
}
