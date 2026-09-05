using System.Reflection;

if (args.Length != 1)
{
    Console.Error.WriteLine("Usage: VerifyMaxNodes <dotnet-gcdump.dll>");
    return 2;
}

var assembly = Assembly.LoadFrom(Path.GetFullPath(args[0]));
var readerType = assembly.GetType("DotNetHeapDumpGraphReader", throwOnError: true)!;
var method = readerType.GetMethod("GetMaxNodeCount", BindingFlags.Static | BindingFlags.NonPublic)
    ?? throw new InvalidOperationException("GetMaxNodeCount was not found.");

VerifyValue(null, 10_000_000);
VerifyValue("20000000", 20_000_000);
VerifyValue(int.MaxValue.ToString(), int.MaxValue);
VerifyInvalid("0");
VerifyInvalid("-1");
VerifyInvalid("abc");
VerifyInvalid("2147483648");

Console.WriteLine("Verified default, configured, maximum, zero, negative, malformed, and overflow values.");
return 0;

void VerifyValue(string? configuredValue, int expected)
{
    Environment.SetEnvironmentVariable("DOTNET_GCDUMP_MAX_NODES", configuredValue);
    var actual = (int)method.Invoke(null, null)!;
    if (actual != expected)
    {
        throw new InvalidOperationException($"Expected {expected}, got {actual}.");
    }
}

void VerifyInvalid(string configuredValue)
{
    Environment.SetEnvironmentVariable("DOTNET_GCDUMP_MAX_NODES", configuredValue);
    try
    {
        method.Invoke(null, null);
        throw new InvalidOperationException($"Value '{configuredValue}' was accepted.");
    }
    catch (TargetInvocationException exception) when (exception.InnerException is InvalidOperationException)
    {
    }
}
