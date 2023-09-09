//
//  MyMetalView.swift
//  Mandelbrot
//
//  Created by Roy Sianez on 12/7/22.
//

import SwiftUI
import Metal
import MetalKit

struct MyMetalView: UIViewControllerRepresentable {
    let scale: Float
    let dx: Float
    let dy: Float
    
    func makeUIViewController(context: Context) -> UIViewController {
        RendererVC()
    }
    
    func updateUIViewController(_ controller: UIViewController, context: Context) {
        let controller = controller as! RendererVC
        controller.renderer.scale = scale
        controller.renderer.dx = dx
        controller.renderer.dy = dy
    }
}

private class RendererVC: UIViewController {
    let renderer = Renderer()
    
    override var view: UIView! {
        get {
            renderer.view
        }
        set {}
    }
}

private class Renderer: NSObject, MTKViewDelegate {
    let view: MTKView
    let pso: MTLRenderPipelineState
    let squarePoints: MTLBuffer
    let sizeBuffer: MTLBuffer
    let viewportBuffer: MTLBuffer
    let paramsBuffer: MTLBuffer
    
    var scale = Float(1.0)
    var dx = Float(0.0)
    var dy = Float(0.0)
    
    override init() {
        view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()!
        squarePoints = view.device!.makeBuffer(
            length: Self._squarePoints.count * MemoryLayout<Point>.stride
        )!
        squarePoints.contents().copyMemory(
            from: Self._squarePoints, byteCount: squarePoints.length)
        sizeBuffer = view.device!.makeBuffer(length: MemoryLayout<SIMD2<Float32>>.size)!
        viewportBuffer = view.device!.makeBuffer(length: MemoryLayout<Float32>.stride * 5)!
        paramsBuffer = view.device!.makeBuffer(length: MemoryLayout<Float32>.stride * 5)!
        let library = view.device!.makeDefaultLibrary()!
        let psoDescripton = MTLRenderPipelineDescriptor()
        psoDescripton.colorAttachments[0].pixelFormat = .bgra8Unorm
        psoDescripton.vertexFunction = library.makeFunction(name: "v_main")!
        psoDescripton.fragmentFunction = library.makeFunction(name: "f_main")!
        pso = try! view.device!.makeRenderPipelineState(descriptor: psoDescripton)
        
        super.init()
        
        view.delegate = self
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    }
    
    func setViewport(scale: Float, dx: Float, dy: Float) {
        let ptr = viewportBuffer.contents()
        ptr.storeBytes(of: scale, as: Float.self)
        (ptr + 4).storeBytes(of: dx, as: Float.self)
        (ptr + 8).storeBytes(of: dy, as: Float.self)
    }
    
    func setParams(iters: UInt32, partialSquare: Float, partialAdd: Float, power: Float, addition: Float) {
        let ptr = paramsBuffer.contents()
        ptr.storeBytes(of: iters, as: UInt32.self)
        (ptr + 4).storeBytes(of: partialSquare, as: Float.self)
        (ptr + 8).storeBytes(of: partialAdd, as: Float.self)
        (ptr + 12).storeBytes(of: power, as: Float.self)
        (ptr + 16).storeBytes(of: addition, as: Float.self)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        sizeBuffer.contents().storeBytes(
            of: [Float(size.width), Float(size.height)], as: SIMD2<Float32>.self)
    }
    
    private var renderStarted = Date.now
    private var isRendering = false
    private var progress: Double = 0
    func draw(in view: MTKView) {
        if isRendering { return }
        isRendering = true
        
        setViewport(scale: scale, dx: dx, dy: dy)
        if renderStarted.distance(to: .now) >= 3 {
            progress += 0.005
        }
        let pmod = progress.truncatingRemainder(dividingBy: 1.0)
        func clamp(_ x: Double) -> Double {
            x < 0 ? 0 : (x > 1 ? 1 : x)
        }
        setParams(
            iters: UInt32(progress),
            partialSquare: Float(clamp(pmod * 2)),
            partialAdd: Float(clamp(pmod * 2 - 1)),
            power: 2.0,
            addition: 1.0
        )
        
        let queue = view.device!.makeCommandQueue()!
        let buffer = queue.makeCommandBuffer()!
        let rpd = view.currentRenderPassDescriptor!
        let encoder = buffer.makeRenderCommandEncoder(descriptor: rpd)!
        encoder.setRenderPipelineState(pso)
        encoder.setVertexBuffer(squarePoints, offset: 0, index: 0)
        encoder.setFragmentBuffer(sizeBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(viewportBuffer, offset: 0, index: 1)
        encoder.setFragmentBuffer(paramsBuffer, offset: 0, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: Self._squarePoints.count)
        encoder.endEncoding()
        buffer.present(view.currentDrawable!)
        buffer.addCompletedHandler { _ in
            self.isRendering = false
        }
        buffer.commit()
    }
    
    typealias Point = SIMD3<Float>
    static let _squarePoints: [Point] = [
        [-1, -1, 0],
        [-1,  1, 0],
        [ 1,  1, 0],
        [-1, -1, 0],
        [ 1,  1, 0],
        [ 1, -1, 0],
    ]
}
