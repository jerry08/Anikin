using System.Collections.Generic;
using Juro;

namespace Anikin.Models;

public class ModuleListGroup<T> : List<T>
{
    public Module Module { get; }

    public ModuleListGroup(Module module, List<T> items)
        : base(items)
    {
        Module = module;
    }
}
