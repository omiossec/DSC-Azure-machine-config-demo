configuration demoDevTo {

    Import-DscResource -ModuleName 'PSDSCResources'
    
    Registry Registydemo
    {
        Ensure      = "Present"  
        Key         = "HKEY_LOCAL_MACHINE\SOFTWARE\ExampleKey1"
        ValueName   = "TestValue"
        ValueData   = "TestData"
        valueType  = "String"
    }

}