//
//  DECtalkExtensionMainView.swift
//  DECtalkExtension
//
//  Created by Camden Bopp on 12/4/25.
//

import SwiftUI

struct DECtalkExtensionMainView: View {
    var parameterTree: ObservableAUParameterGroup

    var body: some View {
        ParameterSlider(param: parameterTree.global.gain)
    }
}
