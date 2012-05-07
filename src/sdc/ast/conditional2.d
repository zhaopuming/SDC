module sdc.ast.conditional2;

import sdc.location;
import sdc.ast.declaration2;
import sdc.ast.statement2;

/**
 * Version Conditional
 */
class Version(ItemType) if(is(ItemType == Statement) || is(ItemType == Declaration)) : ItemType {
	string versionId;
	ItemType[] items;
	
	this(Location location, string versionId, ItemType[] items) {
		super(location, DeclarationType.Conditional);
		
		this.versionId = versionId;
		this.items = items;
	}
}

/**
 * Version Conditional with else
 */
class VersionElse(ItemType) : Version!ItemType {
	ItemType[] elseItems;
	
	this(Location location, string versionId, ItemType[] items, ItemType[] elseItems) {
		super(location, versionId, items);
		
		this.elseItems = elseItems;
	}
}

/**
 * Version definition (ie version = FOOBAR)
 */
class VersionDefinition : Declaration {
	string versionId;
	
	this(Location location, string versionId) {
		super(location, DeclarationType.Conditional);
		
		this.versionId = versionId;
	}
}

