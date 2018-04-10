

module rwslist;

import llist.slist;

import core.sync.rwmutex;


///A bundle of values for the SList payload.
private struct Bundle(T) {
	T payload;
	ReadWriteMutex mutex;
}
private Bundle!T newBundle(T)() {
	auto b = Bundle!T();
	b.initialize;
	return b;
}
private Bundle!T newBundle(T)(T payload) {
	Bundle!T b = Bundle!T(payload);
	b.initialize;
	return b;
}
private void initialize(T)(ref Bundle!T bundle) {
	bundle.mutex = new ReadWriteMutex;
}

class RwSList(T) {
	private alias NodeT = Node!(Bundle!T)*;
	NodeT slist;
	NodeT last;
	this() {
		slist = new Node!(Bundle!T);
		slist.payload = newBundle!T();
		last = slist;
	}
	void iterate(bool delegate(const(T)) callback) {
		NodeT node=slist;
		while (true) {
			//---lock
			node.payload.mutex.reader.lock;
			NodeT lockedNode = node;
			scope(exit) lockedNode.payload.mutex.reader.unlock;
			//---empty
			if (node.empty) break;
			//---callback
			if (!callback(node.payload.payload)) break;
			//---move to next
			node = node.next;
			//---unlock
			// Done in `scope(exit)`
		}
	}
	void writeIterate(bool delegate(T, void delegate() remove) callback) {
		NodeT lastNode=null;
		NodeT node=slist;
		while (true) {
			//---lock
			node.payload.mutex.writer.lock;
			//---empty
			if (node.empty) {
				lastNode.payload.mutex.writer.unlock;
				node.payload.mutex.writer.unlock;
				break;
			}
			//---callback
			if (!callback(node.payload.payload, (){lastNode.removeNext;})) break;
			//---unlock old node (does not need to happen after "move to next" because `last` does not get used)
			if (lastNode!=null) {
				lastNode.payload.mutex.writer.unlock;
			}
			//---move to next
			lastNode = node;
			node = node.next;
		}
	}
	void put(T value) {
		last.payload.mutex.writer.lock;
		NodeT lockedNode = last;
		scope(exit) lockedNode.payload.mutex.writer.unlock;
		
		last.append(newBundle(value));
		last = last.next;
		last.payload = newBundle!T();
	}
}



unittest {
	import std.stdio;
	
	class A {
		int a = 0;
		uint[5] b = [5652,144,1,684,888];
		this(int a) {
			this.a = a;
		}
	}
	
	RwSList!A list = new RwSList!A;
	
	list.put(new A(1));
	list.put(new A(2));
	list.put(new A(3));
	list.put(new A(4));
	list.put(new A(5));
	list.put(new A(6));
	list.put(new A(7));
	
	list.iterate((const A a){a.a.writeln; a.b.writeln; return true;});
	list.writeIterate((A a, void delegate() remove){a.a++; a.b.writeln; return true;});
	list.iterate((const A a){a.a.writeln; a.b.writeln; return true;});
}




