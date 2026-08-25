import LaTeXSwiftUI
import SwiftUI

struct FormulaText: View {
    let source: String

    var body: some View {
        LaTeX(source)
            .parsingMode(.onlyEquations)
            .ignoreStringFormatting()
            .blockMode(.blockViews)
            .errorMode(.original)
            .renderingStyle(.original)
            .script(.custom(1.5))
            .font(.title2.bold())
            .foregroundColor(.white)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
