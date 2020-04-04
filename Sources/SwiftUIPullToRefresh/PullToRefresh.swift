//
//  Spinner.swift
//  PullToRefresh
//
//  Created by András Samu on 2019. 09. 15..
//  Copyright © 2019. András Samu. All rights reserved.
//

import SwiftUI

public struct RefreshableNavigationView<Content: View>: View {
    let content: () -> Content
    let action: () -> Void
    @Binding public var showRefreshView: Bool
    @State public var pullStatus: CGFloat = 0
    var displayMode: NavigationDisplayMode
    var title: String
    var offsetY: CGFloat {
        self.displayMode == .large ? 34 : 0
    }

    public init(title: String, showRefreshView: Binding<Bool>, displayMode: NavigationDisplayMode = .large, action: @escaping () -> Void ,@ViewBuilder content: @escaping () -> Content) {
        self.action = action
        self.content = content
        self._showRefreshView = showRefreshView
        self.displayMode = displayMode
        self.title = title
    }
    
    public var body: some View {
        NavigationView {
            RefreshableList(showRefreshView: $showRefreshView, pullStatus: $pullStatus, displayMode: self.displayMode, action: self.action) {
                self.content()
            }
            .navigationBarTitle("\(self.title)", displayMode: self.displayMode == .large ? .large : .inline)
        }
        .onAppear{
            UITableView.appearance().separatorColor = .clear
        }
    }
}

public struct RefreshableList<Content: View>: View {
    @Binding var showRefreshView: Bool
    @Binding var pullStatus: CGFloat
    let action: () -> Void
    let content: () -> Content
    let displayMode: NavigationDisplayMode
    var threshold: CGFloat = 100.0
    
    @State private var previousScrollOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var frozen: Bool = false
    
    init(showRefreshView: Binding<Bool>, pullStatus: Binding<CGFloat>, displayMode: NavigationDisplayMode = .inline, action: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self._showRefreshView = showRefreshView
        self._pullStatus = pullStatus
        self.action = action
        self.content = content
        self.displayMode = displayMode
    }
    
    public var body: some View {
       
        ZStack(alignment: .top) {
            List{
                MovingView()
                if self.showRefreshView && self.frozen && self.displayMode == .inline {
                    EmptyRow()
                }
                content()
            }
            .background(FixedView())
            .environment(\.defaultMinListRowHeight, 0)
            .onPreferenceChange(RefreshableKeyTypes.PrefKey.self) { values in
                self.refreshLogic(values: values)
            }
            PullToRefreshView(showRefreshView: $showRefreshView, pullStatus: $pullStatus)
                .offset(y: self.displayMode == .large ? -90 : 0)
        }
            
    }
    
    func refreshLogic(values: [RefreshableKeyTypes.PrefData]) {
        DispatchQueue.main.async {
            // Calculate scroll offset
            let movingBounds = values.first { $0.vType == .movingView }?.bounds ?? .zero
            let fixedBounds = values.first { $0.vType == .fixedView }?.bounds ?? .zero
            
            // 6 is the list top padding
            self.scrollOffset  = movingBounds.minY - fixedBounds.minY - 6
            self.pullStatus = self.scrollOffset / 100
            
            // Crossing the threshold on the way down, we start the refresh process
            if !self.showRefreshView && (self.scrollOffset > self.threshold && self.previousScrollOffset <= self.threshold) {
                self.showRefreshView = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                     self.action()
                }
            }
            
            if self.showRefreshView {
                // Crossing the threshold on the way up, we add a space at the top of the scrollview
                if self.previousScrollOffset > self.threshold && self.scrollOffset <= self.threshold {
                    self.frozen = true
                }
            } else {
                // remove the first empty row inside the list view.
                self.frozen = false
            }
            
            // Update last scroll offset
            self.previousScrollOffset = self.scrollOffset
        }
    }
}

struct Spinner: View {
    @Binding var percentage: CGFloat
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(1...12, id: \.self) { i in
                    Rectangle()
                        .fill(Color.gray)
                        .cornerRadius(1)
                        .frame(width: proxy.frame(in: .local).width/12, height: proxy.frame(in: .local).height/4)
                        .opacity(self.percentage * 12 >= CGFloat(i) ? Double(i)/12 : 0)
                        .offset(y: -proxy.frame(in: .local).width/3)
                        .rotationEffect(.degrees(Double(30 * i)), anchor: .center)
                }
            }
        }.frame(width: 40, height: 40)
    }
}

struct RefreshView: View {
    @Binding var isRefreshing:Bool
    @Binding var status: CGFloat
    @State var scale: CGFloat = 1.0
    var body: some View {
        ZStack{
            if (!isRefreshing) {
                Spinner(percentage: $status)
            }else{
                ActivityIndicator(isAnimating: .constant(true), style: .large)//                        .scaleEffect(self.scale)
            }
        }
        .frame(height: 60)
    }
}

struct EmptyRow: View {
    var body: some View {
        Color.clear
            .frame(height: 60)
    }
}

struct PullToRefreshView: View {
    @Binding var showRefreshView: Bool
    @Binding var pullStatus: CGFloat
    
    var body: some View {
        RefreshView(isRefreshing: self.$showRefreshView, status: self.$pullStatus)
    }
}

struct FixedView: View {
    var body: some View {
        GeometryReader { proxy in
            Color
                .clear
                .preference(key: RefreshableKeyTypes.PrefKey.self, value: [RefreshableKeyTypes.PrefData(vType: .fixedView, bounds: proxy.frame(in: .global))])
        }
    }
}

struct MovingView: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: RefreshableKeyTypes.PrefKey.self, value: [RefreshableKeyTypes.PrefData(vType: .movingView, bounds: proxy.frame(in: .global))])
        }.frame(height: 0)
    }
}

struct ActivityIndicator: UIViewRepresentable {

    @Binding var isAnimating: Bool
    let style: UIActivityIndicatorView.Style

    func makeUIView(context: UIViewRepresentableContext<ActivityIndicator>) -> UIActivityIndicatorView {
        return UIActivityIndicatorView(style: style)
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ActivityIndicator>) {
        isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
    }
}

struct RefreshableKeyTypes {
    enum ViewType: Int {
        case movingView
        case fixedView
    }
    
    struct PrefData: Equatable {
        let vType: ViewType
        let bounds: CGRect
    }

    struct PrefKey: PreferenceKey {
        static var defaultValue: [PrefData] = []

        static func reduce(value: inout [PrefData], nextValue: () -> [PrefData]) {
            value.append(contentsOf: nextValue())
        }

        typealias Value = [PrefData]
    }
}

struct Spinner_Previews: PreviewProvider {
    static var previews: some View {
        Spinner(percentage: .constant(1))
    }
}

public enum NavigationDisplayMode {
    case inline
    case large
}
