using System.Threading.Tasks;

namespace Anikin.Views.Popups;

// https://stackoverflow.com/a/77989533
public delegate Task CloseHandler<T>(T result);
