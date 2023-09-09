//
//  ContentView.swift
//  Mandelbrot
//
//  Created by Roy Sianez on 12/7/22.
//

import SwiftUI

struct ContentView: View {
    @State var scale = Float(0.5)
    @State var dx = Float(0.4)
    @State var dy = Float(0.0)
    
    @State var tempScale = Float(1.0)
    @State var tempDx = Float(0.0)
    @State var tempDy = Float(0.0)
    
    var body: some View {
        GeometryReader { proxy in
            MyMetalView(scale: scale, dx: dx, dy: dy)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dx = tempDx + Float(value.translation.width / proxy.size.width) / scale * 2
                            dy = tempDy + Float(value.translation.height / proxy.size.height) / scale * 2
                        }
                        .onEnded { _ in
                            tempDx = dx
                            tempDy = dy
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = tempScale * Float(value)
                        }
                        .onEnded { _ in
                            tempScale = scale
                        }
                )
        }
            .ignoresSafeArea(.all)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
