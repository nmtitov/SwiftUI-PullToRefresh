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
        .offset(x: 0, y: self.showRefreshView ? self.offsetY : 0)
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
    var threshold: CGFloat {displayMode == .large ? 186 : 100 }
    
    var listOffSetY: CGFloat {
        self.displayMode == .large ? -40 : self.showRefreshView ? 0 : -70
    }
    
    init(showRefreshView: Binding<Bool>, pullStatus: Binding<CGFloat>, displayMode: NavigationDisplayMode = .inline, action: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self._showRefreshView = showRefreshView
        self._pullStatus = pullStatus
        self.action = action
        self.content = content
        self.displayMode = displayMode
    }
    
    public var body: some View {
        List{
            PullToRefreshView(showRefreshView: $showRefreshView, pullStatus: $pullStatus, displayMode: self.displayMode)
            content()
        }
        .onPreferenceChange(RefreshableKeyTypes.PrefKey.self) { values in
            guard let bounds = values.first?.bounds else { return }
            self.pullStatus = CGFloat((bounds.origin.y - (self.displayMode == .large ? 106 : 24)) / 80)
            self.refresh(offset: bounds.origin.y)
        }
        .offset(y: self.listOffSetY)
    }
    
    func refresh(offset: CGFloat) {
        if(offset > self.threshold && self.showRefreshView == false) {
            self.showRefreshView = true
            DispatchQueue.main.async {
                self.action()
            }
            
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
    var body: some View {
        HStack{
            Spacer()
            VStack(alignment: .center){
                if (!isRefreshing) {
                    Spinner(percentage: $status)
                }else{
                    ActivityIndicator(isAnimating: .constant(true), style: .large)
                }
                Text(isRefreshing ? "Loading" : "Pull to refresh").font(.caption)
            }
            Spacer()
        }
    }
}

struct PullToRefreshView: View {
    @Binding var showRefreshView: Bool
    @Binding var pullStatus: CGFloat
    var displayMode: NavigationDisplayMode = .large
    
    var body: some View {
        GeometryReader{ geometry in
                RefreshView(isRefreshing: self.$showRefreshView, status: self.$pullStatus)
                    .opacity(Double((geometry.frame(in: CoordinateSpace.global).origin.y - (self.displayMode == .large ? 106 : 24)) / 80))
                    .preference(key: RefreshableKeyTypes.PrefKey.self, value: [RefreshableKeyTypes.PrefData(bounds: geometry.frame(in: CoordinateSpace.global))])
                    .offset(y: self.displayMode == .large ? -90 : 0)
        }
        .frame(height: self.displayMode == .large ? 40 : 70)
        
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
    
    struct PrefData: Equatable {
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
