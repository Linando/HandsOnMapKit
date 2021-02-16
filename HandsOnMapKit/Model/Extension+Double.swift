//
//  Extension+Double.swift
//  HandsOnMapKit
//
//  Created by Allicia Viona Sagi on 22/12/20.
//

import Foundation

extension Double {
    func string(fractionDigits:Int) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
