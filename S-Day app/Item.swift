//
//  Item.swift
//  S-Day app
//
//  Created by 何哲浩 on 2026/3/8.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
