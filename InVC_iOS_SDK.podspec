

Pod::Spec.new do |spec|

  

  spec.name         = "InVC_iOS_SDK"
  spec.version      = "1.0.7"
  spec.summary      = "A short description of InVC_iOS_SDK."

  
  spec.description  = "A short description of InVC_iOS_SDK."

  spec.homepage     = "https://github.com/Sowjanyappl/iOS_P2P_SDK_inVC.git"
  

  spec.license      = "MIT"
  

  spec.author             = { "Sowjanyappl" => "sowjanya@peoplelinkvc.com" }
  

  


  

  spec.source       = { :git => "https://github.com/Sowjanyappl/iOS_P2P_SDK_inVC.git", :tag => "#{spec.version}" }


  

  spec.source_files  = "InVC_iOS_SDK/*.{h,swift}"
  spec.exclude_files = "Classes/Exclude"

   spec.dependency "GoogleWebRTC"
   
   spec.dependency "NWWebSocket"


  


 

end
