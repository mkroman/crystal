require "thread"

lib LibGC("gc")
  fun init = GC_init
  fun malloc = GC_malloc(size : UInt32) : Void*
  fun malloc_atomic = GC_malloc_atomic(size : UInt32) : Void*
  fun realloc = GC_realloc(ptr : Void*, size : UInt32) : Void*
  fun free = GC_free(ptr : Void*)
  fun collect_a_little = GC_collect_a_little : Int32
  fun collect = GC_gcollect
  fun add_roots = GC_add_roots(low : Void*, high : Void*)
  fun enable = GC_enable
  fun disable = GC_disable

  type Finalizer : Void*, Void* ->
  fun register_finalizer = GC_register_finalizer(obj : Void*, fn : Finalizer, cd : Void*, ofn : Finalizer*, ocd : Void**)
  fun invoke_finalizers = GC_invoke_finalizers : Int32
end

# Boehm GC requires to use GC_pthread_create and GC_pthread_join instead of pthread_create and pthread_join
lib PThread
  fun create = GC_pthread_create(thread : Thread*, attr : Void*, start : Void* ->, arg : Void*)
  fun join = GC_pthread_join(thread : Thread, value : Void**) : Int32
end

fun __crystal_malloc(size : UInt32) : Void*
  LibGC.malloc(size)
end

fun __crystal_realloc(ptr : Void*, size : UInt32) : Void*
  LibGC.realloc(ptr, size)
end

module GC
  def self.init
    LibGC.init
  end

  def self.collect
    LibGC.collect
  end

  def self.enable
    LibGC.enable
  end

  def self.disable
    LibGC.disable
  end

  def self.free(pointer : Void*)
    LibGC.free(pointer)
  end

  def self.add_finalizer(object : T)
    if object.responds_to?(:finalize)
      LibGC.register_finalizer(Pointer(Void).new(object.object_id),
        ->(obj : Void*, data : Void*) {
          same_object = obj as T
          if same_object.responds_to?(:finalize)
            same_object.finalize
          end
        }, nil, nil, nil)
      nil
    end
  end
end
